import XCTest
@testable import TidyCore

final class DisplayCoordinatorTests: XCTestCase {
    private var coordinator: DisplayCoordinator?

    override func setUp() {
        super.setUp()
        coordinator = DisplayCoordinator()
    }

    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }

    // MARK: - TC-P0-033: 目标屏幕-有焦点窗口

    func test_有焦点窗口_返回窗口所在屏幕() {
        guard let coord = coordinator else { return }
        let provider = MockScreenProvider(screens: [
            ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), screenID: 1, isMain: true),
            ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), screenID: 2)
        ])
        let window = WindowInfo(
            id: 1,
            axRef: AXUIElementCreateSystemWide(),
            frame: CGRect(x: 2000, y: 500, width: 800, height: 600),
            ownerPID: 1,
            title: "Test"
        )
        let result = coord.targetScreen(for: window, provider: provider)
        XCTAssertEqual(result.screenID, 2)
    }

    // MARK: - TC-P0-034: 目标屏幕-无焦点窗口

    func test_无焦点窗口_返回主屏幕() {
        guard let coord = coordinator else { return }
        let provider = MockScreenProvider(screens: [
            ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), screenID: 1, isMain: true),
            ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), screenID: 2)
        ])
        let result = coord.targetScreen(for: nil, provider: provider)
        XCTAssertEqual(result.screenID, 1)
    }

    // MARK: - TC-P0-035: 无屏幕时返回默认值

    func test_无屏幕_返回零帧默认值() {
        guard let coord = coordinator else { return }
        let provider = MockScreenProvider(screens: [])
        let result = coord.targetScreen(for: nil, provider: provider)
        XCTAssertEqual(result.frame, .zero)
        XCTAssertTrue(result.isMain)
    }

    // MARK: - TC-P0-036: 窗口不在任何屏幕内

    func test_窗口不在任何屏幕_返回主屏幕() {
        guard let coord = coordinator else { return }
        let provider = MockScreenProvider(screens: [
            ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), screenID: 1, isMain: true)
        ])
        let window = WindowInfo(
            id: 1,
            axRef: AXUIElementCreateSystemWide(),
            frame: CGRect(x: -5000, y: -5000, width: 100, height: 100),
            ownerPID: 1,
            title: "Offscreen"
        )
        let result = coord.screenContaining(window: window, provider: provider)
        XCTAssertEqual(result.screenID, 1)
    }
}

// MARK: - 测试用 Mock

private final class MockScreenProvider: ScreenInfoProviding {
    private let screenList: [ScreenInfo]

    init(screens: [ScreenInfo]) {
        self.screenList = screens
    }

    func screens() -> [ScreenInfo] { screenList }

    func mainScreen() -> ScreenInfo? { screenList.first { $0.isMain } }
}
