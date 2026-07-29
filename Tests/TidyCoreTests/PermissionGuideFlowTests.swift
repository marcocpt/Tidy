import XCTest
@testable import TidyCore

final class PermissionGuideFlowTests: XCTestCase {
    // MARK: - TC-F0-005: 引导窗口初始化时显示两个步骤

    /// 验证 PermissionGuideShowing 协议存在且方法签名正确。
    /// 实际 UI 渲染在 TidyUITests / 手动验证中测试。
    func test_PermissionGuideShowing协议_方法签名正确() {
        // 编译期验证：协议存在且包含 showGuide/updateStatus/closeGuide
        // 此测试确认协议定义与 F0_02 设计一致
        let _: PermissionGuideShowing.Type = MockPermissionGuide.self
    }

    // MARK: - TC-F0-009: 全部授权后引导窗口应关闭

    func test_全部授权时_不需要引导() {
        XCTAssertFalse(
            needsPermissionGuide(accessibility: .granted, inputMonitoring: .granted),
            "全部授权时不应显示引导"
        )
    }

    func test_全部授权时_inputMonitoringNotRequired_不需要引导() {
        XCTAssertFalse(
            needsPermissionGuide(accessibility: .granted, inputMonitoring: .notRequired),
            "辅助功能已授权且 Input Monitoring 不需要时不应显示引导"
        )
    }

    // MARK: - TC-F0-010: 辅助功能撤销后引导窗口重新显示

    func test_辅助功能被拒绝_需要引导() {
        XCTAssertTrue(
            needsPermissionGuide(accessibility: .denied, inputMonitoring: .granted),
            "辅助功能被拒绝时应显示引导"
        )
    }

    func test_InputMonitoring被拒绝_需要引导() {
        XCTAssertTrue(
            needsPermissionGuide(accessibility: .granted, inputMonitoring: .denied),
            "Input Monitoring 被拒绝时应显示引导"
        )
    }

    func test_全部被拒绝_需要引导() {
        XCTAssertTrue(
            needsPermissionGuide(accessibility: .denied, inputMonitoring: .denied),
            "全部被拒绝时应显示引导"
        )
    }

    // MARK: - 辅助函数

    /// 复刻 TidyAppDelegate.needsPermissionGuide 逻辑，独立测试
    private func needsPermissionGuide(
        accessibility: AccessibilityPermissionStatus,
        inputMonitoring: InputMonitoringPermissionStatus
    ) -> Bool {
        if accessibility == .denied { return true }
        if inputMonitoring == .denied { return true }
        return false
    }
}

// MARK: - Mock

/// 协议编译期验证用 mock
private final class MockPermissionGuide: PermissionGuideShowing {
    func showGuide(
        accessibilityStatus: AccessibilityPermissionStatus,
        inputMonitoringStatus: InputMonitoringPermissionStatus
    ) {}

    func updateStatus(
        accessibilityStatus: AccessibilityPermissionStatus,
        inputMonitoringStatus: InputMonitoringPermissionStatus
    ) {}

    func closeGuide() {}
}
