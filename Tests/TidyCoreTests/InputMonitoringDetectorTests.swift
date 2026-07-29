import Combine
import XCTest
@testable import TidyCore

final class InputMonitoringDetectorTests: XCTestCase {
    private var detector: InputMonitoringDetector?
    private var cancellables: Set<AnyCancellable>?

    override func setUp() {
        super.setUp()
        detector = InputMonitoringDetector()
        cancellables = []
    }

    override func tearDown() {
        detector?.stopMonitoring()
        detector = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - TC-F0-001: Input Monitoring 权限状态查询

    func test_权限状态查询_返回有效值() {
        guard let detector = detector else { return }
        let status = detector.status
        XCTAssertTrue(
            status == .granted || status == .denied || status == .notRequired,
            "权限状态应为 granted、denied 或 notRequired"
        )
    }

    // MARK: - TC-F0-002: 权限监听启动后状态发布者可订阅

    func test_监听启动后_状态发布者可订阅() {
        guard let detector = detector, var cancellables = cancellables else { return }
        detector.startMonitoring(interval: 0.1)

        let expectation = expectation(description: "状态发布者可订阅")
        var receivedStatuses: [InputMonitoringPermissionStatus] = []

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

    // MARK: - TC-F0-003: 停止监听后不再发布

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

    // MARK: - TC-F0-004: macOS 12 不需要时返回 notRequired

    func test_静态查询_与实例状态一致() {
        guard let detector = detector else { return }
        let staticStatus = InputMonitoringDetector.checkPermission()
        let instanceStatus = detector.status
        XCTAssertEqual(staticStatus, instanceStatus)
    }

    func test_静态查询_返回有效状态() {
        let status = InputMonitoringDetector.checkPermission()
        XCTAssertTrue(
            status == .granted || status == .denied || status == .notRequired,
            "静态查询应返回有效状态"
        )
    }
}
