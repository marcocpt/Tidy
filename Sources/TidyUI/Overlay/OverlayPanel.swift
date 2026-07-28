import AppKit
import TidyCore

// MARK: - 覆盖层数据模型

/// 覆盖层单项数据，表示一个待标注的窗口位置与标签。
///
/// 架构不变量 INV-003：覆盖层坚持原生窗口框架。
public struct OverlayItem {
    /// 标签字母（a-z）
    public let label: Character
    /// 标签应出现的目标矩形，基于屏幕坐标
    public let frame: CGRect
    /// 是否为当前选中项
    public var isSelected: Bool

    public init(label: Character, frame: CGRect, isSelected: Bool = false) {
        self.label = label
        self.frame = frame
        self.isSelected = isSelected
    }
}

// MARK: - 覆盖层显示协议

/// 覆盖层显示协议，定义窗口标签覆盖层的显示、隐藏与更新行为。
///
/// 架构不变量 INV-003：覆盖层坚持原生窗口框架。
public protocol OverlayDisplaying {
    /// 在指定屏幕区域显示覆盖层标签。
    func show(items: [OverlayItem], on screenFrame: CGRect)
    /// 隐藏覆盖层。
    func hide()
    /// 更新已显示的标签项。
    func update(items: [OverlayItem])
}

// MARK: - 覆盖层布局常量

private enum OverlayLayout {
    static let labelSize = CGSize(width: 40, height: 40)
    static let cornerRadius: CGFloat = 8
    static let fontSize: CGFloat = 18
    static let backgroundColor = NSColor(white: 0, alpha: 0.6)
    static let selectedBackgroundColor = NSColor(
        red: 0.2,
        green: 0.5,
        blue: 0.9,
        alpha: 0.8
    )
}

// MARK: - 覆盖层面板

/// 基于 NSPanel 的窗口标签覆盖层。
///
/// 使用 .nonactivatingPanel + .borderless 确保不抢焦点，
/// level 设为 .floating + 1 确保位于普通窗口之上，
/// ignoresMouseEvents = true 实现鼠标穿透。
/// 架构不变量 INV-003：覆盖层坚持原生窗口框架。
public final class OverlayPanel: OverlayDisplaying {
    private let panel: NSPanel
    private var labelViews: [Character: OverlayLabelView] = [:]

    public init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level.floating + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
    }

    /// 在指定屏幕区域显示覆盖层标签。
    public func show(items: [OverlayItem], on screenFrame: CGRect) {
        panel.setFrame(screenFrame, display: true)
        clearLabels()
        for item in items {
            let labelView = OverlayLabelView(
                label: item.label,
                isSelected: item.isSelected
            )
            let origin = CGPoint(
                x: item.frame.midX - OverlayLayout.labelSize.width / 2,
                y: item.frame.midY - OverlayLayout.labelSize.height / 2
            )
            labelView.frame = CGRect(origin: origin, size: OverlayLayout.labelSize)
            panel.contentView?.addSubview(labelView)
            labelViews[item.label] = labelView
        }
        panel.orderFrontRegardless()
    }

    /// 隐藏覆盖层。
    public func hide() {
        panel.orderOut(nil)
        clearLabels()
    }

    /// 更新已显示的标签项。
    public func update(items: [OverlayItem]) {
        for item in items {
            labelViews[item.label]?.isSelected = item.isSelected
        }
    }

    // MARK: - 私有方法

    private func clearLabels() {
        labelViews.values.forEach { $0.removeFromSuperview() }
        labelViews.removeAll()
    }
}

// MARK: - 标签视图

/// 单个标签视图，绘制半透明圆角矩形与居中字母。
private final class OverlayLabelView: NSView {
    private let label: Character
    private let textField: NSTextField

    var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    init(label: Character, isSelected: Bool = false) {
        self.label = label
        self.isSelected = isSelected
        textField = NSTextField(labelWithString: String(label))
        super.init(frame: .zero)
        configureTextField()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        textField.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        let bgColor = isSelected
            ? OverlayLayout.selectedBackgroundColor
            : OverlayLayout.backgroundColor
        bgColor.setFill()
        let path = NSBezierPath(
            roundedRect: bounds,
            xRadius: OverlayLayout.cornerRadius,
            yRadius: OverlayLayout.cornerRadius
        )
        path.fill()
        super.draw(dirtyRect)
    }

    // MARK: - 私有方法

    private func configureTextField() {
        wantsLayer = true
        textField.font = NSFont.systemFont(
            ofSize: OverlayLayout.fontSize,
            weight: .bold
        )
        textField.textColor = .white
        textField.alignment = .center
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.isEditable = false
        textField.isSelectable = false
        addSubview(textField)
    }
}
