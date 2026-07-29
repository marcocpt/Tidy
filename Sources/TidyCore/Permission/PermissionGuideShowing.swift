import Foundation

/// 权限引导显示协议，解耦 TidyCore 与 TidyUI（INV-001 / INV-008）。
///
/// TidyCore 定义此协议，TidyUI 的 PermissionGuideWindow 实现它，
/// TidyApp 在初始化时注入。
public protocol PermissionGuideShowing: AnyObject {
    /// 显示权限引导窗口
    func showGuide(
        accessibilityStatus: AccessibilityPermissionStatus,
        inputMonitoringStatus: InputMonitoringPermissionStatus
    )
    /// 更新权限状态
    func updateStatus(
        accessibilityStatus: AccessibilityPermissionStatus,
        inputMonitoringStatus: InputMonitoringPermissionStatus
    )
    /// 关闭引导窗口
    func closeGuide()
}
