import ApplicationServices
import Foundation

// MARK: - 编排状态

/// Tidy 编排状态机
///
/// 根据架构契约 INV-006：状态机转换必须单向且可逆。
/// idle → arranging → selecting → working，working/selecting → idle。
/// 任何非法转换应被视为错误。
public enum TidyState: Equatable {
    /// 空闲——未编排任何窗口
    case idle
    /// 编排中——正在枚举、布局、排列窗口
    case arranging
    /// 选择中——窗口已排列，等待用户按字母键选择
    case selecting
    /// 工作中——已选中一个窗口并最大化
    case working
}

// MARK: - 编排协议

/// 编排协调协议
///
/// 职责：协调 hotkey → enumerate → layout → arrange → overlay → select → maximize → restore 完整流程。
/// 根据架构契约 INV-008：跨组件通信通过协议。
/// 根据架构契约 INV-006：状态机转换必须单向且可逆。
/// 根据架构契约 INV-009：快照与还原必须成对且原子。
/// 根据架构契约 INV-010：权限缺失时不得执行窗口操作。
public protocol TidyOrchestrating {
    /// 触发编排流程（枚举窗口 → 计算布局 → 排列窗口 → 进入选择阶段）
    ///
    /// 仅在 .idle 状态下可调用，其他状态下忽略。
    /// 根据架构契约 INV-010：调用前应确认辅助功能权限已授予。
    func activate()

    /// 按字母标签选择窗口并最大化
    ///
    /// 仅在 .selecting 状态下可调用。
    /// - Parameter label: 字母标签（a-z）
    func selectWindow(label: Character)

    /// 还原所有窗口并回到空闲状态
    ///
    /// 在 .selecting 或 .working 状态下可调用。
    /// 根据架构契约 INV-009：还原必须使用编排前的快照。
    func deactivate()

    /// 当前编排状态
    var state: TidyState { get }
}

// MARK: - 编排控制器

/// Tidy 编排控制器
///
/// 职责：协调窗口枚举、布局计算、窗口排列、事件拦截与窗口还原的完整流程。
/// 不负责：不获取前台 PID（需要 AppKit，由 App 层通过 frontmostPID 注入）；
/// 不渲染覆盖层（TidyUI 的职责）；不判断权限（PermissionDetector 的职责）。
///
/// 根据架构契约 INV-006：状态机转换必须单向且可逆。
/// 根据架构契约 INV-009：快照与还原必须成对且原子。
/// 根据架构契约 INV-010：权限缺失时不得执行窗口操作。
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
public final class TidyOrchestrator: TidyOrchestrating {
    /// 当前编排状态
    public private(set) var state: TidyState = .idle

    /// 前台 App 的 PID，由 App 层设置（需要 AppKit 访问 NSWorkspace）
    ///
    /// 默认为 0，表示未设置。App 层在激活编排前必须设置此值。
    public var frontmostPID: pid_t = 0

    /// 排列前的窗口位置快照
    ///
    /// 根据架构契约 INV-009：快照与还原必须成对且原子。
    private var positionSnapshot: [CGWindowID: CGRect] = [:]

    /// 当前排列的窗口列表
    private var arrangedWindows: [WindowInfo] = []

    /// 当前布局单元格列表
    private var layoutCells: [LayoutCell] = []

    private let windowEnumerator: WindowEnumerating
    private let windowManipulator: WindowManipulating
    private let layoutCalculator: GridLayoutCalculating
    private let displayCoordinator: DisplayCoordinating
    private let screenProvider: ScreenInfoProviding
    private let hotkeyRegistrar: HotkeyRegistrating
    private let eventTapManager: EventTapManaging

    /// 创建编排控制器
    /// - Parameters:
    ///   - windowEnumerator: 窗口枚举器
    ///   - windowManipulator: 窗口操作器
    ///   - layoutCalculator: 网格布局计算器
    ///   - displayCoordinator: 屏幕协调器
    ///   - screenProvider: 屏幕信息提供者
    ///   - hotkeyRegistrar: 热键注册器
    ///   - eventTapManager: 事件拦截管理器
    public init(
        windowEnumerator: WindowEnumerating,
        windowManipulator: WindowManipulating,
        layoutCalculator: GridLayoutCalculating,
        displayCoordinator: DisplayCoordinating,
        screenProvider: ScreenInfoProviding,
        hotkeyRegistrar: HotkeyRegistrating,
        eventTapManager: EventTapManaging
    ) {
        self.windowEnumerator = windowEnumerator
        self.windowManipulator = windowManipulator
        self.layoutCalculator = layoutCalculator
        self.displayCoordinator = displayCoordinator
        self.screenProvider = screenProvider
        self.hotkeyRegistrar = hotkeyRegistrar
        self.eventTapManager = eventTapManager
    }

    /// 触发编排流程
    ///
    /// 根据架构契约 INV-006：仅在 .idle 状态下可执行。
    /// 根据架构契约 INV-010：调用前应确认辅助功能权限已授予。
    public func activate() {
        guard state == .idle else { return }
        state = .arranging

        let focusedWindow = windowManipulator.focusedWindow(forPID: frontmostPID)
        let targetScreen = displayCoordinator.targetScreen(
            for: focusedWindow,
            provider: screenProvider
        )

        let windows = windowEnumerator.enumerateVisibleWindows(forPID: frontmostPID)
        guard !windows.isEmpty else {
            state = .idle
            return
        }

        positionSnapshot = windowManipulator.snapshotWindows(windows)
        arrangedWindows = windows

        let cells = layoutCalculator.calculateLayout(
            windowCount: windows.count,
            screen: targetScreen
        )
        layoutCells = cells

        applyLayout(cells, windows: windows)

        state = .selecting
        startKeyEventTap()
    }

    /// 按字母标签选择窗口并最大化
    ///
    /// 根据架构契约 INV-006：仅在 .selecting 状态下可执行。
    public func selectWindow(label: Character) {
        guard state == .selecting else { return }

        guard let cell = layoutCells.first(where: { $0.label == label }) else {
            return
        }
        guard cell.windowIndex < arrangedWindows.count else { return }

        let window = arrangedWindows[cell.windowIndex]
        let screen = displayCoordinator.screenContaining(
            window: window,
            provider: screenProvider
        )

        let maximizedFrame = screen.frame.insetBy(dx: 4, dy: 4)
        windowManipulator.setFrame(maximizedFrame, for: window)

        state = .working
        eventTapManager.stopTap()
    }

    /// 还原所有窗口并回到空闲状态
    ///
    /// 根据架构契约 INV-009：还原必须使用编排前的快照。
    public func deactivate() {
        guard state == .selecting || state == .working else { return }

        windowManipulator.restoreWindows(
            from: positionSnapshot,
            windows: arrangedWindows
        )

        positionSnapshot = [:]
        arrangedWindows = []
        layoutCells = []
        state = .idle

        eventTapManager.stopTap()
    }

    // MARK: - 私有方法

    /// 将布局单元格应用到窗口
    private func applyLayout(_ cells: [LayoutCell], windows: [WindowInfo]) {
        for cell in cells {
            guard cell.windowIndex < windows.count else { break }
            let window = windows[cell.windowIndex]
            windowManipulator.setFrame(cell.frame, for: window)
        }
    }

    /// 启动键盘事件拦截
    ///
    /// 根据架构契约 INV-007：输入拦截仅在编排选择阶段启用。
    private func startKeyEventTap() {
        eventTapManager.startTap { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }
    }

    /// 处理拦截到的键盘事件
    private func handleKeyEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        // A-Z 键码范围：0x00(A) - 0x19(Z)
        guard keyCode >= 0 && keyCode <= 25 else { return false }
        let scalarValue = Int(UnicodeScalar("a").value) + Int(keyCode)
        guard let scalar = UnicodeScalar(scalarValue) else { return false }
        let label = Character(scalar)
        selectWindow(label: label)
        return true
    }
}
