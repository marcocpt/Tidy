import XCTest
@testable import TidyCore

final class TidyCoreTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertEqual(TidyCore.version, "0.1.0")
    }

    /// 验证 TidyCore 源文件不引入 AppKit
    ///
    /// 对应 AC-P0-012（SPM 骨架可编译）中"TidyCore 不引入 AppKit 依赖"的编译器层面断言。
    /// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
    /// 扫描 Sources/TidyCore/ 下所有 .swift 文件，断言无 `import AppKit`。
    func test_TidyCore源文件不引入AppKit() {
        let testFile = URL(fileURLWithPath: #file)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesDir = packageRoot.appendingPathComponent("Sources/TidyCore")

        guard let enumerator = FileManager.default.enumerator(atPath: sourcesDir.path) else {
            XCTFail("无法访问 Sources/TidyCore 目录")
            return
        }

        var checkedFiles = 0
        for case let path as String in enumerator {
            guard path.hasSuffix(".swift") else { continue }
            let fileURL = sourcesDir.appendingPathComponent(path)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                XCTFail("无法读取文件: \(path)")
                continue
            }
            checkedFiles += 1
            XCTAssertFalse(
                content.contains("import AppKit"),
                "TidyCore 不应 import AppKit（文件: \(path)）。依赖方向约束见架构契约 INV-001。"
            )
        }

        XCTAssertGreaterThan(checkedFiles, 0, "应至少检查一个源文件")
    }
}
