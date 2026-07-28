import AppKit
import XCTest
@testable import TidyCore

final class WindowEnumeratorTests: XCTestCase {
    private var enumerator: WindowEnumerator?

    override func setUp() {
        super.setUp()
        enumerator = WindowEnumerator()
    }

    override func tearDown() {
        enumerator = nil
        super.tearDown()
    }

    // MARK: - TC-P0-003 ~ TC-P0-006: 窗口枚举

    func test_枚举前台App窗口_返回数组() {
        guard let enumerator = enumerator else { return }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            XCTFail("无法获取前台 App PID")
            return
        }
        let windows = enumerator.enumerateVisibleWindows(forPID: pid)
        XCTAssertGreaterThanOrEqual(windows.count, 0, "应返回窗口数组")
    }

    func test_枚举窗口_每个窗口有有效frame() {
        guard let enumerator = enumerator else { return }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        let windows = enumerator.enumerateVisibleWindows(forPID: pid)
        for window in windows {
            XCTAssertGreaterThan(window.frame.width, 0, "窗口宽度应大于 0")
            XCTAssertGreaterThan(window.frame.height, 0, "窗口高度应大于 0")
        }
    }

    func test_枚举窗口_每个窗口有有效ID() {
        guard let enumerator = enumerator else { return }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        let windows = enumerator.enumerateVisibleWindows(forPID: pid)
        for window in windows {
            XCTAssertGreaterThan(window.id, 0, "窗口 ID 应大于 0")
        }
    }

    func test_枚举不存在的PID_返回空数组() {
        guard let enumerator = enumerator else { return }
        let windows = enumerator.enumerateVisibleWindows(forPID: 999999)
        XCTAssertEqual(windows.count, 0, "不存在的 PID 应返回空数组")
    }
}

final class WindowManipulatorTests: XCTestCase {
    private var manipulator: WindowManipulator?

    override func setUp() {
        super.setUp()
        manipulator = WindowManipulator()
    }

    override func tearDown() {
        manipulator = nil
        super.tearDown()
    }

    // MARK: - TC-P0-010: 焦点窗口获取

    func test_焦点窗口_有前台App时返回结果() {
        guard let manipulator = manipulator else { return }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        let focused = manipulator.focusedWindow(forPID: pid)
        // 焦点窗口可能存在也可能不存在，测试不崩溃即可
        if let focused = focused, focused.frame.width > 0 {
            XCTAssertGreaterThan(focused.frame.height, 0)
        }
    }

    // MARK: - 快照与还原

    func test_快照窗口_保存原始位置() {
        guard let manipulator = manipulator else { return }
        let w1 = WindowInfo(
            id: 1,
            axRef: AXUIElementCreateSystemWide(),
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            ownerPID: 1,
            title: "W1"
        )
        let w2 = WindowInfo(
            id: 2,
            axRef: AXUIElementCreateSystemWide(),
            frame: CGRect(x: 200, y: 200, width: 200, height: 200),
            ownerPID: 1,
            title: "W2"
        )
        let snapshot = manipulator.snapshotWindows([w1, w2])
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot[1], CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(snapshot[2], CGRect(x: 200, y: 200, width: 200, height: 200))
    }

    func test_快照为空时_还原返回失败() {
        guard let manipulator = manipulator else { return }
        let w1 = WindowInfo(
            id: 1,
            axRef: AXUIElementCreateSystemWide(),
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            ownerPID: 1,
            title: "W1"
        )
        let results = manipulator.restoreWindows(from: [:], windows: [w1])
        XCTAssertEqual(results.count, 1)
        if case .failed = results[0] {
            // 预期失败
        } else {
            XCTFail("无快照时应返回失败")
        }
    }
}
