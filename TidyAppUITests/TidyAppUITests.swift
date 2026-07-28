import XCTest

/// TidyApp UI 测试
///
/// 验证 Tidy App 的可自动化 UI 行为。
///
/// **平台限制说明**（对应 [P0_02_设计文档](docs/phases/P0_技术探针/P0_02_设计文档.md) 6.1 节）：
/// XCUITest 在 macOS 上无法访问 `NSStatusItem`（系统状态栏不在 App 的 accessibility hierarchy 中），
/// 因此 AC-P0-008（状态栏可用：图标显示、菜单点击、菜单项回调）无法通过 XCUITest 自动化验证，
/// 降级为手动验证（见 [artifacts/manual-verification-checklist.md](docs/phases/P0_技术探针/artifacts/manual-verification-checklist.md) 2.4）。
/// Overlay 出现/消失与 Esc 流程因依赖编排触发（需 AX 权限 + ≥2 可见窗口），在 XCUITest 环境下不稳定，
/// 亦降级为手动验证（见同清单 2.3）。
///
/// 本 target 仅保留 App 启动 smoke test，验证 App 不崩溃启动。
/// P0 阶段不引入测试钩子（test hook）以避免过度工程化；F1 阶段若需稳定自动化可评估测试模式方案。
final class TidyAppUITests: XCTestCase {
    /// 测试 App 启动不崩溃
    ///
    /// 这是 P0 阶段唯一可稳定自动化的 UI 行为。
    /// 验证 App 能在合理时间内完成启动并保持运行状态。
    func testAppLaunchesWithoutCrash() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.waitForExistence(timeout: 5), "App 应在 5 秒内完成启动")
    }
}
