import Foundation

// MARK: - 屏幕信息

/// 屏幕可见区域与标识符。
///
/// 将 NSScreen 关键信息抽象为纯值类型，
/// 使 TidyCore 不依赖 AppKit（INV-001）。
public struct ScreenInfo: Equatable {
    /// 屏幕可见区域（不含 Dock 和菜单栏）
    public let frame: CGRect
    /// 屏幕唯一标识符
    public let screenID: UInt32
    /// 是否为主屏幕
    public let isMain: Bool

    /// 创建屏幕信息实例
    /// - Parameters:
    ///   - frame: 屏幕可见区域
    ///   - screenID: 屏幕唯一标识符
    ///   - isMain: 是否为主屏幕
    public init(frame: CGRect, screenID: UInt32, isMain: Bool = false) {
        self.frame = frame
        self.screenID = screenID
        self.isMain = isMain
    }
}

// MARK: - 屏幕信息提供者

/// 屏幕信息抽象协议，解耦 TidyCore 与 AppKit（INV-001）。
///
/// 由 TidyUI 层实现，将 NSScreen 转换为 ScreenInfo，
/// 保证 TidyCore 可在无 AppKit 依赖下编译和测试。
/// 根据架构契约 INV-008：跨组件通信通过协议。
public protocol ScreenInfoProviding {
    /// 返回所有可用屏幕信息
    func screens() -> [ScreenInfo]
    /// 返回主屏幕信息，无屏幕时返回 nil
    func mainScreen() -> ScreenInfo?
}

// MARK: - 布局单元格

/// 网格布局中的单个单元格，对应一个待排列的窗口。
///
/// label 按字母 a-z 分配，由左到右、由上到下遍历网格生成。
public struct LayoutCell {
    /// 字母标签（a-z）
    public let label: Character
    /// 窗口目标矩形
    public let frame: CGRect
    /// 窗口在列表中的 0 起始索引
    public let windowIndex: Int

    /// 创建布局单元格
    /// - Parameters:
    ///   - label: 字母标签
    ///   - frame: 窗口目标矩形
    ///   - windowIndex: 窗口索引
    public init(label: Character, frame: CGRect, windowIndex: Int) {
        self.label = label
        self.frame = frame
        self.windowIndex = windowIndex
    }
}

// MARK: - 网格布局计算协议

/// 网格布局计算协议，将窗口数量与屏幕信息映射为布局单元格列表。
///
/// 根据架构契约 INV-008：跨组件通信通过协议。
public protocol GridLayoutCalculating {
    /// 根据窗口数量和屏幕信息计算自适应网格布局
    /// - Parameters:
    ///   - windowCount: 待排列窗口数量
    ///   - screen: 目标屏幕信息
    /// - Returns: 布局单元格数组，最多 26 个（a-z）
    func calculateLayout(windowCount: Int, screen: ScreenInfo) -> [LayoutCell]
}

// MARK: - 网格布局计算器

/// 自适应网格布局计算器。
///
/// 布局规则：
/// - 偶数窗口：标准网格（2→1x2, 4→2x2, 6→2x3）
/// - 奇数窗口（≥3）：a 占左侧全高，剩余窗口在右侧 2 行网格
///   - 3→a 半 + 右 2x1, 5→a 1/3 + 右 2x2, 7→a 1/4 + 右 2x3
/// 每个单元格内缩 8pt 作为窗口目标矩形。
/// 纯 Foundation 实现，不依赖 AppKit（INV-001）。
public final class GridLayoutCalculator: GridLayoutCalculating {
    /// 字母表标签，a-z 共 26 个
    private static let labels: [Character] = Array("abcdefghijklmnopqrstuvwxyz")

    /// 创建网格布局计算器实例
    public init() {}

    public func calculateLayout(windowCount: Int, screen: ScreenInfo) -> [LayoutCell] {
        let capped = min(windowCount, 26)
        guard capped > 0 else { return [] }

        let padding: CGFloat = 8.0

        // 单窗口：占满全屏
        if capped == 1 {
            let frame = screen.frame.insetBy(dx: padding, dy: padding)
            return [LayoutCell(label: "a", frame: frame, windowIndex: 0)]
        }

        // 偶数窗口：标准网格
        if capped % 2 == 0 {
            return standardGrid(count: capped, screen: screen, padding: padding)
        }

        // 奇数窗口（3, 5, 7...）：a 占左侧全高，剩余窗口在右侧 2 行网格
        return splitLayout(count: capped, screen: screen, padding: padding)
    }

    // MARK: - 标准网格（偶数窗口）

    /// 标准网格布局：均匀划分行列
    private func standardGrid(
        count: Int,
        screen: ScreenInfo,
        padding: CGFloat
    ) -> [LayoutCell] {
        let (rows, cols) = evenGridDimensions(count: count)
        let cellWidth = screen.frame.width / CGFloat(cols)
        let cellHeight = screen.frame.height / CGFloat(rows)

        var cells: [LayoutCell] = []
        var index = 0

        for row in 0..<rows {
            for col in 0..<cols {
                guard index < count else { break }
                let x = screen.frame.origin.x + CGFloat(col) * cellWidth + padding
                let y = screen.frame.origin.y + CGFloat(row) * cellHeight + padding
                let width = cellWidth - padding * 2
                let height = cellHeight - padding * 2
                let label = Self.labels[index]
                let frame = CGRect(x: x, y: y, width: width, height: height)
                cells.append(LayoutCell(label: label, frame: frame, windowIndex: index))
                index += 1
            }
        }

        return cells
    }

    /// 偶数窗口的网格行列数
    /// - 2→(1,2), 4→(2,2), 6→(2,3), 8→(2,4), 10+→接近正方形
    private func evenGridDimensions(count: Int) -> (rows: Int, cols: Int) {
        if count == 2 { return (1, 2) }
        if count == 4 { return (2, 2) }
        if count == 6 { return (2, 3) }
        if count == 8 { return (2, 4) }
        // 10+: 尽量接近正方形
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        return (rows, cols)
    }

    // MARK: - 分割布局（奇数窗口 ≥3）

    /// a 占左侧全高，剩余窗口在右侧 2 行网格
    /// - 3→a 占 1/2 + 右侧 2x1
    /// - 5→a 占 1/3 + 右侧 2x2
    /// - 7→a 占 1/4 + 右侧 2x3
    private func splitLayout(
        count: Int,
        screen: ScreenInfo,
        padding: CGFloat
    ) -> [LayoutCell] {
        let remaining = count - 1
        let rightCols = remaining / 2
        let totalCols = 1 + rightCols

        let leftWidth = screen.frame.width / CGFloat(totalCols)
        let rightWidth = screen.frame.width - leftWidth
        let rightCellWidth = rightWidth / CGFloat(rightCols)
        let rightCellHeight = screen.frame.height / 2

        var cells: [LayoutCell] = []

        // a 窗口：左侧全高
        let aFrame = CGRect(
            x: screen.frame.origin.x + padding,
            y: screen.frame.origin.y + padding,
            width: leftWidth - padding * 2,
            height: screen.frame.height - padding * 2
        )
        cells.append(LayoutCell(label: "a", frame: aFrame, windowIndex: 0))

        // 剩余窗口：右侧 2 行网格
        var index = 1
        for row in 0..<2 {
            for col in 0..<rightCols {
                guard index < count else { break }
                let x = screen.frame.origin.x + leftWidth + CGFloat(col) * rightCellWidth + padding
                let y = screen.frame.origin.y + CGFloat(row) * rightCellHeight + padding
                let width = rightCellWidth - padding * 2
                let height = rightCellHeight - padding * 2
                let label = Self.labels[index]
                let frame = CGRect(x: x, y: y, width: width, height: height)
                cells.append(LayoutCell(label: label, frame: frame, windowIndex: index))
                index += 1
            }
        }

        return cells
    }
}
