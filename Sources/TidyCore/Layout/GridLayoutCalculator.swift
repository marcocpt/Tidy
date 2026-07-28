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
/// 根据窗口数量选择最优行列比，将屏幕均分为网格单元格，
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

        let (rows, cols) = gridDimensions(count: capped)
        let cellWidth = screen.frame.width / CGFloat(cols)
        let cellHeight = screen.frame.height / CGFloat(rows)
        let padding: CGFloat = 8.0

        var cells: [LayoutCell] = []
        var index = 0

        for row in 0..<rows {
            for col in 0..<cols {
                guard index < capped else { break }
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

    // MARK: - 私有辅助

    /// 计算最优网格行列数，使空单元格最少
    ///
    /// 策略：窗口数 1 为单格；2-3 用 2 列；4-6 在 2-3 行列中选最优；
    /// 7+ 用 ceil(sqrt(n)) 正方网格。
    private func gridDimensions(count: Int) -> (rows: Int, cols: Int) {
        if count <= 1 { return (1, 1) }
        if count == 2 { return (1, 2) }
        if count == 3 { return (2, 2) }

        if count <= 6 {
            var best = (rows: 3, cols: 3, empty: 9 - count)
            for rows in 2...3 {
                for cols in 2...3 {
                    let total = rows * cols
                    if total >= count {
                        let empty = total - count
                        if empty < best.empty
                            || (empty == best.empty && rows < best.rows) {
                            best = (rows, cols, empty)
                        }
                    }
                }
            }
            return (best.rows, best.cols)
        }

        let side = Int(ceil(sqrt(Double(count))))
        return (side, side)
    }
}
