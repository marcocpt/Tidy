import XCTest
@testable import TidyUI

final class TidyUITests: XCTestCase {
    func testModuleVersion() {
        XCTAssertEqual(TidyUI.version, "0.1.0")
    }
}
