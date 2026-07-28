import Foundation

/// 屏幕协调协议
///
/// 根据架构契约 INV-008：跨组件通信通过协议。
/// 根据架构契约 INV-006：目标屏幕由焦点窗口中心决定。
public protocol DisplayCoordinating {
    /// 解析目标屏幕——编排窗口时使用的目标屏幕
    ///
    /// 根据架构契约 INV-006：目标屏幕由焦点窗口中心决定。
    /// - Parameters:
    ///   - focusedWindow: 当前焦点窗口，nil 表示无焦点
    ///   - provider: 屏幕信息提供者
    /// - Returns: 目标屏幕信息
    func targetScreen(
        for focusedWindow: WindowInfo?,
        provider: ScreenInfoProviding
    ) -> ScreenInfo

    /// 查找窗口所在屏幕
    ///
    /// - Parameters:
    ///   - window: 待定位窗口
    ///   - provider: 屏幕信息提供者
    /// - Returns: 包含该窗口中心点的屏幕，未匹配时返回主屏幕
    func screenContaining(
        window: WindowInfo,
        provider: ScreenInfoProviding
    ) -> ScreenInfo
}

// MARK: - 屏幕协调器

/// 屏幕协调器
///
/// 职责：解析窗口编排的目标屏幕；查找窗口所在的屏幕。
/// 不负责：不获取屏幕硬件信息（ScreenInfoProviding 的职责）；
/// 不操作窗口位置（WindowManipulator 的职责）。
///
/// 根据架构契约 INV-006：目标屏幕由焦点窗口中心决定。
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
public final class DisplayCoordinator: DisplayCoordinating {
    public init() {}

    public func targetScreen(
        for focusedWindow: WindowInfo?,
        provider: ScreenInfoProviding
    ) -> ScreenInfo {
        let allScreens = provider.screens()
        guard !allScreens.isEmpty else {
            return ScreenInfo(frame: .zero, screenID: 0, isMain: true)
        }
        guard let focused = focusedWindow else {
            return provider.mainScreen() ?? allScreens[0]
        }
        return screenContaining(window: focused, provider: provider)
    }

    public func screenContaining(
        window: WindowInfo,
        provider: ScreenInfoProviding
    ) -> ScreenInfo {
        let allScreens = provider.screens()
        let matched = allScreens.first { screen in
            containsCenter(screen.frame, windowFrame: window.frame)
        }
        return matched ?? provider.mainScreen() ?? allScreens[0]
    }

    // MARK: - 私有辅助

    private func centerPoint(of frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2
        )
    }

    private func containsCenter(
        _ screenFrame: CGRect,
        windowFrame: CGRect
    ) -> Bool {
        let center = centerPoint(of: windowFrame)
        return screenFrame.contains(center)
    }
}
