import AppKit
import Carbon
import Combine
import os
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
    private var guideShownLogged = false
    private var prevAxStatus: AccessibilityPermissionStatus?
    private var prevImStatus: InputMonitoringPermissionStatus?
    private let permLog = OSLog(subsystem: "com.tidy.windowmanagement", category: "permission")

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
            if !guideShownLogged {
                os_log("tidy.permission event=permission_guide_shown", log: permLog, type: .default)
                guideShownLogged = true
            }
        }
        prevAxStatus = permDetector.status
        prevImStatus = imDetector.status

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

        // MARK: - 状态栏（F0.1：3 状态 + 3 菜单项）

        let statusManager = StatusItemManager()
        statusManager.setup(title: "T", menuItems: [
            StatusMenuItem(title: "触发编排", action: { [weak self] in
                self?.toggleOrchestration()
            }),
            StatusMenuItem.separator(),
            StatusMenuItem(title: "权限设置...", action: { [weak self] in
                self?.openPermissionSettings()
            }),
            StatusMenuItem.separator(),
            StatusMenuItem(title: "退出", action: {
                NSApplication.shared.terminate(nil)
            })
        ])
        self.statusItemManager = statusManager

        // 状态栏图标联动：编排状态变化时更新
        orchestrator.onStateChange = { [weak self] newState in
            DispatchQueue.main.async {
                self?.updateStatusBarIcon()
                // F1: 进入 working 状态时，激活被选中窗口所属的 App（使其重新成为 frontmost）
                // 配合 TidyOrchestrator.selectWindow 中的 AX 窗口激活，
                // 确保"按字母选择后目标窗口成为活动窗口"。
                if newState == .working {
                    self?.activateFrontmostApp()
                }
            }
        }

        // 初始化状态栏图标
        updateStatusBarIcon()

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

        // MARK: - F1 健壮性：Space 切换自动还原 + 目标 App 退出恢复

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppTermination),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    /// F1-002: Space 切换时自动还原
    @objc private func handleSpaceChange() {
        guard let orchestrator = orchestrator,
              orchestrator.state == .selecting || orchestrator.state == .working else { return }
        os_log("tidy.space-change auto-restore", log: permLog, type: .default)
        orchestrator.deactivate()
    }

    /// F1-004: 目标 App 退出时尽力恢复
    @objc private func handleAppTermination(_ notification: Notification) {
        guard let orchestrator = orchestrator,
              orchestrator.state != .idle,
              let info = notification.userInfo,
              let terminatedApp = info[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              terminatedApp.processIdentifier == orchestrator.frontmostPID else { return }
        os_log("tidy.app-terminated auto-restore pid=%d", log: permLog, type: .default, terminatedApp.processIdentifier)
        orchestrator.deactivate()
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

        // 追踪授权状态转换事件（FR-F0-005）
        if let prev = prevAxStatus, prev == .denied, axStatus == .granted {
            os_log("tidy.permission event=accessibility_granted", log: permLog, type: .default)
        }
        if let prev = prevImStatus, prev == .denied, imStatus == .granted {
            os_log("tidy.permission event=input_monitoring_granted", log: permLog, type: .default)
        }

        if needsPermissionGuide(accessibility: axStatus, inputMonitoring: imStatus) {
            guide.showGuide(
                accessibilityStatus: axStatus,
                inputMonitoringStatus: imStatus
            )
        } else {
            // 检查是否从"需要引导"变为"全部授权"
            let wasGuideNeeded = prevAxStatus == .denied || prevImStatus == .denied
            if wasGuideNeeded {
                os_log("tidy.permission event=all_permissions_granted", log: permLog, type: .default)
            }
            // 全部已授权，延迟 1.5 秒关闭（让用户看到成功状态）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.permissionGuide?.closeGuide()
            }
        }

        prevAxStatus = axStatus
        prevImStatus = imStatus
        updateStatusBarIcon()
    }

    // MARK: - 状态栏图标联动（F0.1）

    /// F1: 激活前台 App（让其重新成为 frontmost）
    ///
    /// 在 selectWindow 后调用，配合 TidyOrchestrator 中的 AX 窗口激活，
    /// 让被选中的窗口及其所属 App 成为活动窗口。
    /// 解决"按字母后选择的窗口没有变为活动窗口"问题。
    ///
    /// macOS 14+ 上 NSRunningApplication.activate(options:) 行为变化且经常无效，
    /// 改用 NSWorkspace.shared.openApplication(activates: true) 通过 LaunchServices 激活，
    /// 该 API 在 macOS 12+ 上稳定有效。
    private func activateFrontmostApp() {
        guard let orch = orchestrator, orch.frontmostPID > 0 else { return }
        guard let app = NSRunningApplication(processIdentifier: orch.frontmostPID) else {
            os_log("tidy.activate-app FAIL pid=%d not-found", log: permLog, type: .default, orch.frontmostPID)
            return
        }

        let bundleID = app.bundleIdentifier ?? orch.frontmostBundleID
        guard let bundleURL = app.bundleURL else {
            os_log("tidy.activate-app FAIL pid=%d bundleURL-nil", log: permLog, type: .default, orch.frontmostPID)
            return
        }

        // 通过 LaunchServices 激活目标 App（macOS 12+ 稳定 API）
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                os_log("tidy.activate-app FAIL pid=%d bundle=%{public}@ error=%{public}@",
                       log: self.permLog, type: .default,
                       orch.frontmostPID, bundleID, error.localizedDescription)
            } else {
                os_log("tidy.activate-app ok pid=%d bundle=%{public}@",
                       log: self.permLog, type: .default,
                       orch.frontmostPID, bundleID)
            }
        }
    }

    /// 根据权限和编排状态更新状态栏图标
    private func updateStatusBarIcon() {
        guard let permDetector = permissionDetector,
              let imDetector = inputMonitoringDetector,
              let statusManager = statusItemManager else { return }

        if permDetector.status == .denied || imDetector.status == .denied {
            statusManager.updateTitle("!")
        } else if let orch = orchestrator, orch.state != .idle {
            statusManager.updateTitle("●")
        } else {
            statusManager.updateTitle("T")
        }
    }

    /// 打开权限设置（菜单项回调）
    private func openPermissionSettings() {
        guard let permDetector = permissionDetector,
              let imDetector = inputMonitoringDetector,
              let guide = permissionGuide else { return }
        guide.showGuide(
            accessibilityStatus: permDetector.status,
            inputMonitoringStatus: imDetector.status
        )
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
