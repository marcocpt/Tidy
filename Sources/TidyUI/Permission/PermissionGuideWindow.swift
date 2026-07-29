import AppKit
import SwiftUI
import TidyCore

/// 权限引导窗口
///
/// 实现 PermissionGuideShowing 协议，显示权限引导 UI。
/// 首次启动未授权时显示，授权完成后自动关闭。
public final class PermissionGuideWindow: PermissionGuideShowing {
    private var window: NSWindow?
    private var hostingView: NSHostingView<PermissionGuideView>?

    public init() {}

    public func showGuide(
        accessibilityStatus: AccessibilityPermissionStatus,
        inputMonitoringStatus: InputMonitoringPermissionStatus
    ) {
        guard window == nil else {
            updateStatus(
                accessibilityStatus: accessibilityStatus,
                inputMonitoringStatus: inputMonitoringStatus
            )
            return
        }

        let view = PermissionGuideView(
            accessibilityStatus: accessibilityStatus,
            inputMonitoringStatus: inputMonitoringStatus,
            onOpenAccessibilitySettings: openAccessibilitySettings,
            onOpenInputMonitoringSettings: openInputMonitoringSettings
        )

        let hosting = NSHostingView(rootView: view)
        self.hostingView = hosting

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.title = "Tidy 权限设置"
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func updateStatus(
        accessibilityStatus: AccessibilityPermissionStatus,
        inputMonitoringStatus: InputMonitoringPermissionStatus
    ) {
        guard let hostingView = hostingView else { return }
        hostingView.rootView = PermissionGuideView(
            accessibilityStatus: accessibilityStatus,
            inputMonitoringStatus: inputMonitoringStatus,
            onOpenAccessibilitySettings: openAccessibilitySettings,
            onOpenInputMonitoringSettings: openInputMonitoringSettings
        )
    }

    public func closeGuide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }

    // MARK: - 打开系统设置

    private func openAccessibilitySettings() {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func openInputMonitoringSettings() {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
}

/// 权限引导 SwiftUI 视图
struct PermissionGuideView: View {
    let accessibilityStatus: AccessibilityPermissionStatus
    let inputMonitoringStatus: InputMonitoringPermissionStatus
    let onOpenAccessibilitySettings: () -> Void
    let onOpenInputMonitoringSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tidy 需要权限授权")
                .font(.title2)
                .fontWeight(.semibold)

            // 辅助功能权限步骤
            PermissionStepView(
                title: "辅助功能权限",
                description: "Tidy 需要辅助功能权限来管理窗口位置与大小",
                isGranted: accessibilityStatus == .granted,
                onOpenSettings: onOpenAccessibilitySettings
            )

            // Input Monitoring 权限步骤
            if inputMonitoringStatus != .notRequired {
                PermissionStepView(
                    title: "输入监控权限",
                    description: "Tidy 需要输入监控权限来拦截键盘选择窗口",
                    isGranted: inputMonitoringStatus == .granted,
                    onOpenSettings: onOpenInputMonitoringSettings
                )
            }

            Spacer()

            Text("授权完成后将自动开始工作")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}

/// 单个权限步骤视图
struct PermissionStepView: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(isGranted ? "✓" : "○")
                    .font(.title3)
                    .foregroundColor(isGranted ? .green : .secondary)
                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)

            if !isGranted {
                Button("打开系统设置") {
                    onOpenSettings()
                }
                .buttonStyle(.link)
            }
        }
    }
}
