import Foundation

// MARK: - 覆盖层显示协议（跨层抽象）

/// 覆盖层显示协议，解耦 TidyCore 与 TidyUI（INV-001 / INV-008）。
///
/// TidyCore 定义此协议，TidyUI 的 OverlayPanel 实现它，
/// TidyApp 在初始化时注入。协议使用 LayoutCell（已在 TidyCore 中），
/// 避免引入 TidyUI 类型。
public protocol OverlayShowing: AnyObject {
    /// 显示覆盖层标签
    /// - Parameters:
    ///   - cells: 布局单元格列表（含字母标签与 frame）
    ///   - screenFrame: 目标屏幕可见区域
    func showOverlay(cells: [LayoutCell], on screenFrame: CGRect)
    /// 隐藏覆盖层
    func hideOverlay()
}

// MARK: - 编排状态

/// Tidy 编排状态机
///
/// 根据架构契约 INV-006：状态机转换必须单向且可逆。
/// idle → arranging → selecting → working，working/selecting → idle。
/// 任何非法转换应被视为错误。
public enum TidyState: Equatable {
    /// 空闲——未编排任何窗口
    case idle
    /// 编排中——正在枚举、布局、排列窗口
    case arranging
    /// 选择中——窗口已排列，等待用户按字母键选择
    case selecting
    /// 工作中——已选中一个窗口并最大化
    case working
}

// MARK: - 编排协议

/// 编排协调协议
///
/// 职责：协调 hotkey → enumerate → layout → arrange → overlay → select → maximize → restore 完整流程。
/// 根据架构契约 INV-008：跨组件通信通过协议。
/// 根据架构契约 INV-006：状态机转换必须单向且可逆。
/// 根据架构契约 INV-009：快照与还原必须成对且原子。
/// 根据架构契约 INV-010：权限缺失时不得执行窗口操作。
public protocol TidyOrchestrating {
    /// 触发编排流程（枚举窗口 → 计算布局 → 排列窗口 → 进入选择阶段）
    ///
    /// 仅在 .idle 状态下可调用，其他状态下忽略。
    /// 根据架构契约 INV-010：调用前应确认辅助功能权限已授予。
    func activate()

    /// 按字母标签选择窗口并最大化
    ///
    /// 仅在 .selecting 状态下可调用。
    /// - Parameter label: 字母标签（a-z）
    func selectWindow(label: Character)

    /// 还原所有窗口并回到空闲状态
    ///
    /// 在 .selecting 或 .working 状态下可调用。
    /// 根据架构契约 INV-009：还原必须使用编排前的快照。
    func deactivate()

    /// 热键 toggle：idle 时 activate，selecting/working 时 deactivate
    ///
    /// 对应设计文档 4.2 节状态转换：
    /// - idle + 热键 → arranging
    /// - selecting + 热键 → restoring
    func toggle()

    /// 当前编排状态
    var state: TidyState { get }
}
