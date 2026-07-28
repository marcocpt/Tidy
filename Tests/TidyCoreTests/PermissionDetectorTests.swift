import Combine
import XCTest
@testable import TidyCore

final class PermissionDetectorTests: XCTestCase {
    private var detector: PermissionDetector?
    private var cancellables: Set<AnyCancellable>?

    override func setUp() {
        super.setUp()
        detector = PermissionDetector()
        cancellables = []
    }

    override func tearDown() {
        detector?.stopMonitoring()
        detector = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - TC-P0-001: AX 权限状态查询

    func test_权限状态查询_返回有效状态() {
        guard let detector = detector else { return }
        let status = detector.status
        XCTAssertTrue(
            status == .granted || status == .denied,
            "权限状态应为 granted 或 denied"
        )
    }

    func test_静态查询_与实例状态一致() {
        guard let detector = detector else { return }
        let staticStatus = PermissionDetector.checkAXPermission()
        let instanceStatus = detector.status
        XCTAssertEqual(staticStatus, instanceStatus)
    }

    // MARK: - TC-P0-002: 权限状态变化监听

    func test_监听启动后_状态发布者可订阅() {
        guard let detector = detector, var cancellables = cancellables else { return }
        detector.startMonitoring(interval: 0.1)

        let expectation = expectation(description: "状态发布者可订阅")
        var receivedStatuses: [AccessibilityPermissionStatus] = []

        detector.statusPublisher
            .sink { status in
                receivedStatuses.append(status)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        self.cancellables = cancellables

        wait(for: [expectation], timeout: 2.0)
        detector.stopMonitoring()

        XCTAssertFalse(receivedStatuses.isEmpty, "应至少收到一次状态通知")
    }

    func test_停止监听后_不再发布() {
        guard let detector = detector, var cancellables = cancellables else { return }
        detector.startMonitoring(interval: 0.1)

        let collectExpectation = expectation(description: "收集初始状态")
        var receivedCount = 0

        detector.statusPublisher
            .sink { _ in
                receivedCount += 1
                if receivedCount >= 1 {
                    collectExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        self.cancellables = cancellables

        wait(for: [collectExpectation], timeout: 2.0)
        detector.stopMonitoring()

        let countBefore = receivedCount
        let afterStopExpectation = expectation(description: "停止后等待")
        afterStopExpectation.isInverted = true
        wait(for: [afterStopExpectation], timeout: 1.0)

        XCTAssertEqual(receivedCount, countBefore, "停止后不应有新通知")
    }

    func test_请求权限_不崩溃() {
        guard let detector = detector else { return }
        detector.requestPermission()
    }
}
