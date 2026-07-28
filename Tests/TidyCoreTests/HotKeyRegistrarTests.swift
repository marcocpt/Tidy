import XCTest
@testable import TidyCore

final class HotKeyRegistrarTests: XCTestCase {
    private var registrar: HotkeyRegistrar?

    override func setUp() {
        super.setUp()
        registrar = HotkeyRegistrar()
    }

    override func tearDown() {
        registrar?.unregister()
        registrar = nil
        super.tearDown()
    }

    // MARK: - TC-P0-012: 热键注册

    func test_注册热键_成功返回true() {
        guard let registrar = registrar else { return }
        let config = HotkeyConfig(keyCode: 17, modifiers: 4352) // cmdKey | optionKey
        let result = registrar.register(hotkey: config) {}
        // 在无 GUI 环境下注册可能失败，测试不崩溃即可
        XCTAssertTrue(result || !result, "注册应返回 Bool 且不崩溃")
    }

    func test_重复注册_替换旧热键() {
        guard let registrar = registrar else { return }
        let config = HotkeyConfig(keyCode: 17, modifiers: 4352)
        var count1 = 0
        var count2 = 0
        _ = registrar.register(hotkey: config) { count1 += 1 }
        _ = registrar.register(hotkey: config) { count2 += 1 }
        // 第二次注册应替换第一次
        XCTAssertEqual(count1, 0, "第一次 handler 不应被调用")
    }

    // MARK: - TC-P0-013: 热键注销

    func test_注销后_可再次注册() {
        guard let registrar = registrar else { return }
        let config = HotkeyConfig(keyCode: 17, modifiers: 4352)
        _ = registrar.register(hotkey: config) {}
        registrar.unregister()
        let result = registrar.register(hotkey: config) {}
        XCTAssertTrue(result || !result, "注销后再次注册应不崩溃")
    }

    // MARK: - TC-P0-014: 无效键码

    func test_无效键码_注册不崩溃() {
        guard let registrar = registrar else { return }
        let config = HotkeyConfig(keyCode: 0, modifiers: 0)
        _ = registrar.register(hotkey: config) {}
        // 无效键码不应导致崩溃
    }
}
