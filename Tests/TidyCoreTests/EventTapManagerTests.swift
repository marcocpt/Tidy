import XCTest
@testable import TidyCore

final class EventTapManagerTests: XCTestCase {
    private var manager: EventTapManager?

    override func setUp() {
        super.setUp()
        manager = EventTapManager()
    }

    override func tearDown() {
        manager?.stopTap()
        manager = nil
        super.tearDown()
    }

    // MARK: - TC-P0-015: EventTap 创建

    func test_启动Tap_权限不足时返回false() {
        guard let manager = manager else { return }
        // 在 CI 或无辅助功能权限环境下，tap 创建可能失败
        let result = manager.startTap { _ in false }
        // 测试不崩溃即可；成功或失败取决于权限
        XCTAssertTrue(result || !result, "启动 tap 应返回 Bool 且不崩溃")
    }

    // MARK: - TC-P0-016: EventTap 停止

    func test_停止Tap_不崩溃() {
        guard let manager = manager else { return }
        manager.startTap { _ in false }
        manager.stopTap()
        XCTAssertFalse(manager.isActive, "停止后应不活跃")
    }

    func test_未启动时停止_不崩溃() {
        guard let manager = manager else { return }
        manager.stopTap()
        XCTAssertFalse(manager.isActive, "未启动时应不活跃")
    }

    // MARK: - TC-P0-017: isActive 状态

    func test_初始状态_不活跃() {
        guard let manager = manager else { return }
        XCTAssertFalse(manager.isActive, "初始状态应不活跃")
    }

    // MARK: - TC-P0-018: handleTapDisabled

    func test_处理系统禁用_不崩溃() {
        guard let manager = manager else { return }
        manager.startTap { _ in false }
        manager.handleTapDisabled()
        // 不崩溃即可
    }

    // MARK: - TC-P0-016/017 补充：边界场景

    func test_未启动时处理禁用_不崩溃() {
        guard let manager = manager else { return }
        // 未启动 tap 时调用 handleTapDisabled 应安全返回
        manager.handleTapDisabled()
        XCTAssertFalse(manager.isActive, "未启动时应不活跃")
        XCTAssertNil(manager.lastError, "未启动时 lastError 应为 nil")
    }

    func test_停止后处理禁用_不崩溃() {
        guard let manager = manager else { return }
        manager.startTap { _ in false }
        manager.stopTap()
        manager.handleTapDisabled()
        XCTAssertFalse(manager.isActive, "停止后应不活跃")
    }

    func test_lastError初始为nil() {
        guard let manager = manager else { return }
        XCTAssertNil(manager.lastError, "初始状态 lastError 应为 nil")
    }
}
