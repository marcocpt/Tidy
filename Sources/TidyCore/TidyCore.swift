import Foundation

/// TidyCore — 纯逻辑层，不依赖 AppKit/SwiftUI
///
/// 包含窗口枚举、布局算法、状态机、编排协调、权限检测、窗口操作等核心逻辑。
/// 根据架构契约 INV-001，本模块永不导入或链接任何 UI 框架。
public enum TidyCore {
    /// 模块版本，用于探针验证
    public static let version = "0.1.0"
}
