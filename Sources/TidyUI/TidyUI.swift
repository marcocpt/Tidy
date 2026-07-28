import AppKit
import TidyCore

/// TidyUI — UI 层，包含覆盖层、状态栏、偏好窗口
///
/// 依赖 TidyCore，不依赖 TidyApp。
/// 根据架构契约 INV-003，覆盖层坚持 AppKit，偏好窗口可用 SwiftUI。
public enum TidyUI {
    /// 模块版本，用于探针验证
    public static let version = "0.1.0"
}
