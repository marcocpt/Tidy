import AppKit
import Carbon
import Combine
import TidyCore
import TidyUI

/// TidyApp — 应用入口层
///
/// 依赖 TidyCore 和 TidyUI（通过 local SPM package 引入）。
/// 根据架构契约 INV-002，依赖方向为 App → UI → Core。
/// P0 探针阶段使用 NSApplication 模式，兼容 macOS 12+。
final class TidyAppDelegate: NSObject, NSApplicationDelegate {
    private var orchestrator: TidyOrchestrator?
    private var statusItemManager: StatusItemManager?
    private var overlayPanel: OverlayPanel?
    private var permissionDetector: PermissionDetector?
    private var inputMonitoringDetector: InputMonitoringDetector?
    private var permissionGuide: PermissionGuideWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // MARK: - 权限检测与引导（F0）

        let permDetector = PermissionDetector()
        let imDetector = InputMonitoringDetector()
        self.permissionDetector = permDetector
        self.inputMonitoringDetector = imDetector

        permDetector.startMonitoring()
        imDetector.startMonitoring()

        let guideWindow = PermissionGuideWindow()
        self.permissionGuide = guideWindow

        // 检查是否需要显示权限引导
        if needsPermissionGuide(
            accessibility: permDetector.status,
            inputMonitoring: imDetector.status
        ) {
            guideWindow.showGuide(
                accessibilityStatus: permDetector.status,
                inputMonitoringStatus: imDetector.status
            )
        }

        // 订阅权限状态变化
        permDetector.statusPublisher
            .sink { [weak self] _ in
                self?.handlePermissionChange()
            }
            .store(in: &cancellables)

        imDetector.statusPublisher
            .sink { [weak self] _ in
                self?.handlePermissionChange()
            }
            .store(in: &cancellables)

        // MARK: - 构建依赖图

        let windowEnumerator = WindowEnumerator()
        let windowManipulator = WindowManipulator()
        let layoutCalculator = GridLayoutCalculator()
        let displayCoordinator = DisplayCoordinator()
        let screenProvider = AppScreenProvider()
        let hotkeyRegistrar = HotkeyRegistrar()
        let eventTapManager = EventTapManager()

        let orchestrator = TidyOrchestrator(
            windowEnumerator: windowEnumerator,
            windowManipulator: windowManipulator,
            layoutCalculator: layoutCalculator,
            displayCoordinator: displayCoordinator,
            screenProvider: screenProvider,
            hotkeyRegistrar: hotkeyRegistrar,
            eventTapManager: eventTapManager
        )
        self.orchestrator = orchestrator

        // MARK: - 状态栏

        let statusManager = StatusItemManager()
        statusManager.setup(title: "T", menuItems: [
            StatusMenuItem(title: "触发编排", action: { [weak self] in
                self?.toggleOrchestration()
            }),
            StatusMenuItem.separator(),
            StatusMenuItem(title: "退出", action: {
                NSApplication.shared.terminate(nil)
            })
        ])
        self.statusItemManager = statusManager

        // MARK: - 覆盖层（注入到 orchestrator，跨层适配 OverlayShowing）

        let overlayPanel = OverlayPanel()
        self.overlayPanel = overlayPanel
        orchestrator.setOverlay(overlayPanel)

        // MARK: - 注册热键 ⌘⌥T

        let config = HotkeyConfig(
            keyCode: 17, // T key
            modifiers: UInt32(cmdKey | optionKey)
        )
        hotkeyRegistrar.register(hotkey: config) { [weak self] in
            self?.toggleOrchestration()
        }
    }

    // MARK: - 热键 toggle

    /// 热键/菜单回调：idle 时触发 activate，selecting/working 时触发 deactivate。
    /// 对应设计文档 4.2 节状态转换。
    private func toggleOrchestration() {
        guard let orchestrator = orchestrator else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        orchestrator.frontmostPID = frontmost?.processIdentifier ?? 0
        orchestrator.frontmostBundleID = frontmost?.bundleIdentifier ?? ""
        orchestrator.toggle()
    }

    // MARK: - 权限引导（F0）

    /// 判断是否需要显示权限引导窗口
    private func needsPermissionGuide(
        accessibility: AccessibilityPermissionStatus,
        inputMonitoring: InputMonitoringPermissionStatus
    ) -> Bool {
        if accessibility == .denied { return true }
        if inputMonitoring == .denied { return true }
        return false
    }

    /// 处理权限状态变化
    private func handlePermissionChange() {
        guard let permDetector = permissionDetector,
              let imDetector = inputMonitoringDetector,
              let guide = permissionGuide else { return }

        let axStatus = permDetector.status
        let imStatus = imDetector.status

        if needsPermissionGuide(accessibility: axStatus, inputMonitoring: imStatus) {
            guide.showGuide(
                accessibilityStatus: axStatus,
                inputMonitoringStatus: imStatus
            )
        } else {
            // 全部已授权，延迟 1.5 秒关闭（让用户看到成功状态）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.permissionGuide?.closeGuide()
            }
        }
    }
}

// MARK: - NSScreen → ScreenInfo 桥接

/// 将 NSScreen 信息转换为 TidyCore 的 ScreenInfo，
/// 满足 ScreenInfoProviding 协议（INV-001 / INV-008）。
private final class AppScreenProvider: ScreenInfoProviding {
    func screens() -> [ScreenInfo] {
        NSScreen.screens.enumerated().map { index, screen in
            ScreenInfo(
                frame: screen.visibleFrame,
                screenID: UInt32(index),
                isMain: index == 0
            )
        }
    }

    func mainScreen() -> ScreenInfo? {
        guard let main = NSScreen.main else { return nil }
        return ScreenInfo(
            frame: main.visibleFrame,
            screenID: 0,
            isMain: true
        )
    }
}
