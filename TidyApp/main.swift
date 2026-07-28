import AppKit

// 显式入口点：创建 NSApplication，设置 delegate，运行事件循环
// 注：@main + NSApplicationDelegate 不会自动设置 delegate（无 main nib 时），
// 必须在 main.swift 中显式设置，否则 applicationDidFinishLaunching 不会被调用。
let app = NSApplication.shared
let delegate = TidyAppDelegate()
app.delegate = delegate
app.run()
