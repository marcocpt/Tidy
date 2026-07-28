import XCTest
@testable import TidyCore

final class TidyCoreTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertEqual(TidyCore.version, "0.1.0")
    }
}
