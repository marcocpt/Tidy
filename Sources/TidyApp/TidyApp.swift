import AppKit
import Carbon
import TidyCore
import TidyUI

/// TidyApp — 应用入口层
///
/// 依赖 TidyCore 和 TidyUI。
/// 根据架构契约 INV-002，依赖方向为 App → UI → Core。
/// P0 探针阶段使用 NSApplication 模式，兼容 macOS 12+。
@main
final class TidyAppDelegate: NSObject, NSApplicationDelegate {
    private var orchestrator: TidyOrchestrator?
    private var statusItemManager: StatusItemManager?
    private var overlayPanel: OverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                self?.triggerArrange()
            }),
            StatusMenuItem.separator(),
            StatusMenuItem(title: "退出", action: {
                NSApplication.shared.terminate(nil)
            })
        ])
        self.statusItemManager = statusManager

        // MARK: - 覆盖层

        self.overlayPanel = OverlayPanel()

        // MARK: - 注册热键 ⌘⌥T

        let config = HotkeyConfig(
            keyCode: 17, // T key
            modifiers: UInt32(cmdKey | optionKey)
        )
        hotkeyRegistrar.register(hotkey: config) { [weak self] in
            self?.triggerArrange()
        }
    }

    // MARK: - 触发编排

    private func triggerArrange() {
        guard let orchestrator = orchestrator else { return }
        orchestrator.frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        orchestrator.activate()
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
