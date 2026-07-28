import AppKit
import TidyCore
import TidyUI

/// TidyApp — 应用入口层
///
/// 依赖 TidyCore 和 TidyUI。
/// 根据架构契约 INV-002，依赖方向为 App → UI → Core。
/// P0 探针阶段使用 NSApplication 模式，兼容 macOS 12+。
@main
final class TidyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "T"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "P0 Probe", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}
