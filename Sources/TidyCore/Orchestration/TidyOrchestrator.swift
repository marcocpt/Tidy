import ApplicationServices
import Foundation
import os.log

// MARK: - 覆盖层显示协议（跨层抽象）

/// 覆盖层显示协议，解耦 TidyCore 与 TidyUI（INV-001 / INV-008）。
///
/// TidyCore 定义此协议，TidyUI 的 OverlayPanel 实现它，
/// TidyApp 在初始化时注入。协议使用 LayoutCell（已在 TidyCore 中），
/// 避免引入 TidyUI 类型。
public protocol OverlayShowing: AnyObject {
    /// 显示覆盖层标签
    /// - Parameters:
    ///   - cells: 布局单元格列表（含字母标签与 frame）
    ///   - screenFrame: 目标屏幕可见区域
    func showOverlay(cells: [LayoutCell], on screenFrame: CGRect)
    /// 隐藏覆盖层
    func hideOverlay()
}

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

    /// 热键 toggle：idle 时 activate，selecting/working 时 deactivate
    ///
    /// 对应设计文档 4.2 节状态转换：
    /// - idle + 热键 → arranging
    /// - selecting + 热键 → restoring
    func toggle()

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

    /// 前台 App 的 Bundle ID，由 App 层设置（用于性能日志中的 app 字段）
    ///
    /// 默认为空字符串。App 层在激活编排前应设置此值（来自 NSWorkspace.frontmostApplication?.bundleIdentifier）。
    /// 性能埋点输出格式：`tidy.performance app=<bundle_id> ...`（对应 P0_02 1.6 节）。
    public var frontmostBundleID: String = ""

    /// 排列前的窗口位置快照
    ///
    /// 根据架构契约 INV-009：快照与还原必须成对且原子。
    private var positionSnapshot: [CGWindowID: CGRect] = [:]

    /// 当前排列的窗口列表
    private var arrangedWindows: [WindowInfo] = []

    /// 当前布局单元格列表
    private var layoutCells: [LayoutCell] = []

    /// 当前目标屏幕（用于覆盖层显示与最大化）
    private var targetScreenFrame: CGRect = .zero

    private let windowEnumerator: WindowEnumerating
    private let windowManipulator: WindowManipulating
    private let layoutCalculator: GridLayoutCalculating
    private let displayCoordinator: DisplayCoordinating
    private let screenProvider: ScreenInfoProviding
    private let hotkeyRegistrar: HotkeyRegistrating
    private let eventTapManager: EventTapManaging

    /// 覆盖层显示（由 TidyApp 注入，可为 nil 用于无 UI 测试）
    private weak var overlay: OverlayShowing?

    /// 性能日志（对应 P0_02 1.6 节性能埋点要求）
    private let perfLog = OSLog(
        subsystem: "com.tidy.windowmanagement",
        category: .pointsOfInterest
    )

    /// 创建编排控制器
    /// - Parameters:
    ///   - windowEnumerator: 窗口枚举器
    ///   - windowManipulator: 窗口操作器
    ///   - layoutCalculator: 网格布局计算器
    ///   - displayCoordinator: 屏幕协调器
    ///   - screenProvider: 屏幕信息提供者
    ///   - hotkeyRegistrar: 热键注册器
    ///   - eventTapManager: 事件拦截管理器
    ///   - overlay: 覆盖层显示（可选，由 TidyApp 注入）
    public init(
        windowEnumerator: WindowEnumerating,
        windowManipulator: WindowManipulating,
        layoutCalculator: GridLayoutCalculating,
        displayCoordinator: DisplayCoordinating,
        screenProvider: ScreenInfoProviding,
        hotkeyRegistrar: HotkeyRegistrating,
        eventTapManager: EventTapManaging,
        overlay: OverlayShowing? = nil
    ) {
        self.windowEnumerator = windowEnumerator
        self.windowManipulator = windowManipulator
        self.layoutCalculator = layoutCalculator
        self.displayCoordinator = displayCoordinator
        self.screenProvider = screenProvider
        self.hotkeyRegistrar = hotkeyRegistrar
        self.eventTapManager = eventTapManager
        self.overlay = overlay
    }

    /// 注入覆盖层显示（用于延迟注入场景）
    public func setOverlay(_ overlay: OverlayShowing) {
        self.overlay = overlay
    }

    /// 触发编排流程
    ///
    /// 根据架构契约 INV-006：仅在 .idle 状态下可执行。
    /// 根据架构契约 INV-010：调用前应确认辅助功能权限已授予。
    /// 性能埋点（P0_02 1.6 节）：记录 T0/T1/T2 并输出 os_log。
    public func activate() {
        guard state == .idle else { return }
        let t0 = DispatchTime.now()
        state = .arranging

        let focusedWindow = windowManipulator.focusedWindow(forPID: frontmostPID)
        let targetScreen = displayCoordinator.targetScreen(
            for: focusedWindow,
            provider: screenProvider
        )
        targetScreenFrame = targetScreen.frame

        let windows = windowEnumerator.enumerateVisibleWindows(forPID: frontmostPID)
        guard !windows.isEmpty else {
            state = .idle
            logPerformance(t0: t0, t1: nil, t2: nil, windowCount: 0, success: false)
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
        let t1 = DispatchTime.now()

        // 显示覆盖层（对应设计文档 3. 数据流第 254 行）
        overlay?.showOverlay(cells: cells, on: targetScreenFrame)

        state = .selecting
        startKeyEventTap()
        let t2 = DispatchTime.now()

        logPerformance(t0: t0, t1: t1, t2: t2, windowCount: windows.count, success: true)
    }

    /// 按字母标签选择窗口并最大化
    ///
    /// 根据架构契约 INV-006：仅在 .selecting 状态下可执行。
    public func selectWindow(label: Character) {
        guard state == .selecting else {
            os_log("tidy.debug select skipped: state", log: perfLog, type: .default)
            return
        }

        guard let cell = layoutCells.first(where: { $0.label == label }) else {
            os_log("tidy.debug select skipped: label", log: perfLog, type: .default)
            return
        }
        guard cell.windowIndex < arrangedWindows.count else {
            os_log("tidy.debug select skipped: range", log: perfLog, type: .default)
            return
        }

        let window = arrangedWindows[cell.windowIndex]
        let screen = displayCoordinator.screenContaining(
            window: window,
            provider: screenProvider
        )

        let maximizedFrame = screen.frame.insetBy(dx: 4, dy: 4)
        let result = windowManipulator.setFrame(maximizedFrame, for: window)
        logSelectResult(label: label, window: window, result: result)

        // 隐藏覆盖层（对应设计文档 3. 数据流第 259 行）
        overlay?.hideOverlay()

        state = .working
        eventTapManager.stopTap()
    }

    /// 记录 selectWindow 结果（临时诊断日志，P0 探针阶段）
    private func logSelectResult(
        label: Character,
        window: WindowInfo,
        result: WindowOperationResult
    ) {
        switch result {
        case .success:
            os_log(
                "tidy.debug select ok label=%{public}@ wid=%llu",
                log: perfLog,
                type: .default,
                String(label),
                window.id
            )
        case .failed(_, let reason):
            os_log(
                "tidy.debug select FAIL label=%{public}@ wid=%llu reason=%{public}@",
                log: perfLog,
                type: .default,
                String(label),
                window.id,
                reason
            )
        }
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

        // 隐藏覆盖层（若未隐藏）
        overlay?.hideOverlay()

        positionSnapshot = [:]
        arrangedWindows = []
        layoutCells = []
        targetScreenFrame = .zero
        state = .idle

        eventTapManager.stopTap()
    }

    /// 热键 toggle：idle 时 activate，selecting/working 时 deactivate
    ///
    /// 对应设计文档 4.2 节状态转换：
    /// - idle + 热键 → arranging（触发 activate）
    /// - selecting + 热键 → restoring（触发 deactivate）
    /// - working + 热键 → restoring（触发 deactivate）
    public func toggle() {
        switch state {
        case .idle:
            activate()
        case .selecting, .working:
            deactivate()
        case .arranging:
            break
        }
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
        let success = eventTapManager.startTap { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }
        os_log(
            "tidy.debug EventTap.start success=%d isActive=%d",
            log: perfLog,
            type: .default,
            success,
            eventTapManager.isActive ? 1 : 0
        )
    }

    /// 处理拦截到的键盘事件
    private func handleKeyEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        os_log(
            "tidy.debug EventTap.keyEvent keyCode=%lld",
            log: perfLog,
            type: .default,
            keyCode
        )
        // Mac QWERTY 键盘 keyCode → 字母映射（非线性，不能简单用 97+keyCode）
        let keyCodeToLetter: [Int64: Character] = [
            0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f",
            5: "g", 4: "h", 34: "i", 38: "j", 40: "k", 37: "l",
            46: "m", 45: "n", 31: "o", 35: "p", 12: "q", 15: "r",
            1: "s", 17: "t", 32: "u", 9: "v", 13: "w", 7: "x",
            16: "y", 6: "z"
        ]
        guard let label = keyCodeToLetter[keyCode] else { return false }
        os_log(
            "tidy.debug EventTap.select label=%{public}@",
            log: perfLog,
            type: .default,
            String(label)
        )
        selectWindow(label: label)
        return true
    }

    /// 性能埋点：记录 T0/T1/T2 时间戳并输出到 os_log
    ///
    /// 对应 P0_02 设计文档 1.6 节性能埋点要求：
    /// - T0：收到热键 callback 时刻（activate() 入口）
    /// - T1：所有窗口 AXSetFrame 完成时刻（applyLayout 结束）
    /// - T2：覆盖层与标签可见且可接受输入时刻（overlayPanel.show 完成 + startKeyEventTap 启用）
    /// - Arrange latency = T2 - T0，单位毫秒
    /// - 失败路径也记录 T0 但 T1/T2 可缺失（记为 0）
    ///
    /// 输出格式：`tidy.performance app=<bundle_id> windows=<count> t0=<ms> t1=<ms> t2=<ms> latency=<ms> success=<0|1>`
    private func logPerformance(
        t0: DispatchTime,
        t1: DispatchTime?,
        t2: DispatchTime?,
        windowCount: Int,
        success: Bool
    ) {
        let t0ms = t0.uptimeNanoseconds / 1_000_000
        let t1ms = (t1?.uptimeNanoseconds ?? 0) / 1_000_000
        let t2ms = (t2?.uptimeNanoseconds ?? 0) / 1_000_000
        let latency = t2ms > t0ms ? t2ms - t0ms : 0

        os_log(
            "tidy.performance app=%{public}@ windows=%d t0=%lld t1=%lld t2=%lld latency=%lld success=%d",
            log: perfLog,
            type: .default,
            frontmostBundleID,
            windowCount,
            t0ms,
            t1ms,
            t2ms,
            latency,
            success ? 1 : 0
        )
    }
}
