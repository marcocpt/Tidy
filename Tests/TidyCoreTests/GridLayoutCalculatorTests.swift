import XCTest
@testable import TidyCore

final class GridLayoutCalculatorTests: XCTestCase {
    private var calculator: GridLayoutCalculator?

    override func setUp() {
        super.setUp()
        calculator = GridLayoutCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    // MARK: - TC-P0-025: 单窗口布局

    func test_单窗口_占满屏幕() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 1, screen: screen)
        XCTAssertEqual(cells.count, 1)
        XCTAssertEqual(cells[0].label, "a")
    }

    // MARK: - TC-P0-026: 双窗口布局

    func test_双窗口_2列布局() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 2, screen: screen)
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells[0].label, "a")
        XCTAssertEqual(cells[1].label, "b")
        XCTAssertTrue(cells[0].frame.origin.x < cells[1].frame.origin.x)
    }

    // MARK: - TC-P0-027: 零窗口

    func test_零窗口_返回空数组() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 0, screen: screen)
        XCTAssertTrue(cells.isEmpty)
    }

    // MARK: - TC-P0-028: 最多26个窗口

    func test_超过26窗口_截断为26() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 30, screen: screen)
        XCTAssertEqual(cells.count, 26)
        XCTAssertEqual(cells[0].label, "a")
        XCTAssertEqual(cells[25].label, "z")
    }

    // MARK: - TC-P0-029: 6窗口布局

    func test_6窗口_2x3布局() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 6, screen: screen)
        XCTAssertEqual(cells.count, 6)
    }

    // MARK: - TC-P0-030: 单元格不重叠

    func test_单元格帧_不重叠() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 4, screen: screen)
        for idx in 0..<cells.count {
            for jdx in (idx + 1)..<cells.count {
                let intersection = cells[idx].frame.intersection(cells[jdx].frame)
                XCTAssertTrue(
                    intersection.width <= 0 || intersection.height <= 0,
                    "单元格 \(idx) 和 \(jdx) 不应重叠"
                )
            }
        }
    }

    // MARK: - TC-P0-031: 布局在屏幕内

    func test_所有单元格_在屏幕内() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 4, screen: screen)
        for cell in cells {
            XCTAssertTrue(
                screen.frame.contains(cell.frame),
                "单元格应在屏幕范围内"
            )
        }
    }

    // MARK: - TC-P0-032: 窗口索引递增

    func test_窗口索引_从0递增() {
        guard let calc = calculator else { return }
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            screenID: 1
        )
        let cells = calc.calculateLayout(windowCount: 5, screen: screen)
        for (index, cell) in cells.enumerated() {
            XCTAssertEqual(cell.windowIndex, index)
        }
    }
}
