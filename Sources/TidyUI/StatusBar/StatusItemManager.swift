import AppKit
import TidyCore

// MARK: - 菜单项数据模型

/// 状态栏菜单项描述
///
/// 对应架构契约中状态栏交互的菜单项抽象，
/// 支持普通可点击项与分隔线两种类型。
public struct StatusMenuItem {
    /// 菜单项标题
    public let title: String
    /// 点击回调；分隔线项为 nil
    public let action: (() -> Void)?
    /// 是否为分隔线
    public let isSeparator: Bool

    /// 创建普通菜单项
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.isSeparator = false
    }

    /// 创建全属性菜单项
    public init(title: String, action: (() -> Void)?, isSeparator: Bool) {
        self.title = title
        self.action = action
        self.isSeparator = isSeparator
    }

    /// 创建分隔线菜单项
    public static func separator() -> StatusMenuItem {
        StatusMenuItem(title: "", action: nil, isSeparator: true)
    }
}

// MARK: - 状态栏管理协议

/// 状态栏项管理协议
///
/// 定义状态栏项的创建与更新能力。
/// 实现类负责 NSStatusItem 的生命周期管理，
/// 符合架构契约 INV-005 对 Menu Bar App 入口的要求。
public protocol StatusItemManaging {
    /// 配置状态栏项标题与菜单
    func setup(title: String, menuItems: [StatusMenuItem])
    /// 更新状态栏项标题
    func updateTitle(_ title: String)
}

// MARK: - 菜单项动作目标

/// NSMenuItem target/action 的 ObjC 桥接
///
/// NSMenuItem 的 target/action 机制需要 ObjC 兼容对象，
/// 此类持有闭包并在 action 消息触发时执行。
private final class MenuItemTarget: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func performAction() {
        handler()
    }
}

// MARK: - 状态栏项管理器

/// 状态栏项管理器
///
/// 负责创建、配置和销毁 NSStatusItem。
/// 根据架构契约 INV-005，Tidy 作为 Menu Bar App
/// 必须在状态栏提供可见入口。本管理器确保：
/// - 状态栏项在 setup 时创建且始终存在
/// - 菜单项闭包通过 MenuItemTarget 正确桥接
/// - deinit 时清理状态栏项，避免泄漏
public final class StatusItemManager: StatusItemManaging {
    private var statusItem: NSStatusItem?
    private var menuTargets: [MenuItemTarget] = []

    public init() {}

    deinit {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    /// 配置状态栏项标题与菜单
    ///
    /// - Parameters:
    ///   - title: 状态栏按钮显示的标题
    ///   - menuItems: 菜单项列表，按顺序添加到菜单
    public func setup(title: String, menuItems: [StatusMenuItem]) {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        item.button?.title = title
        let menu = NSMenu()
        menuTargets.removeAll()
        for menuItem in menuItems {
            addMenuItem(menuItem, to: menu)
        }
        item.menu = menu
        statusItem = item
    }

    /// 更新状态栏项标题
    public func updateTitle(_ title: String) {
        statusItem?.button?.title = title
    }

    // MARK: - 私有方法

    private func addMenuItem(_ item: StatusMenuItem, to menu: NSMenu) {
        if item.isSeparator {
            menu.addItem(NSMenuItem.separator())
            return
        }
        let target = MenuItemTarget(handler: item.action ?? {})
        let nsItem = NSMenuItem(
            title: item.title,
            action: #selector(MenuItemTarget.performAction),
            keyEquivalent: ""
        )
        nsItem.target = target
        menu.addItem(nsItem)
        menuTargets.append(target)
    }
}
