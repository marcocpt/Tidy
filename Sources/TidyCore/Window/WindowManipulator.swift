import ApplicationServices
import Foundation
import os.log

/// 窗口操作结果
public enum WindowOperationResult: Sendable, Equatable {
    case success
    case failed(windowID: CGWindowID, reason: String)
}

/// 窗口操作协议
///
/// 根据架构契约 INV-008：跨组件通信通过协议。
public protocol WindowManipulating {
    /// 设置窗口位置与大小
    func setFrame(_ frame: CGRect, for window: WindowInfo) -> WindowOperationResult
    /// 获取焦点窗口
    func focusedWindow(forPID pid: pid_t) -> WindowInfo?
    /// 快照窗口位置
    func snapshotWindows(_ windows: [WindowInfo]) -> [CGWindowID: CGRect]
    /// 还原窗口到快照位置
    func restoreWindows(from snapshot: [CGWindowID: CGRect], windows: [WindowInfo]) -> [WindowOperationResult]
    /// 激活指定窗口为 App 主窗口并聚焦（F1）
    ///
    /// 通过 AX 设置 kAXMainWindowAttribute 与 kAXFocusedWindowAttribute，
    /// 让窗口在所属 App 内成为主窗口并获得焦点。App 本身的前台激活由 App 层负责。
    func activateWindow(_ window: WindowInfo) -> WindowOperationResult
}

/// 窗口操作器
///
/// 职责：AXSetFrame 设置窗口位置、获取焦点窗口、快照与还原。
/// 不负责：不枚举窗口（WindowEnumerator 的职责）；不判断权限（PermissionDetector 的职责）。
///
/// 根据架构契约 INV-005：窗口操作仅通过辅助功能公开接口。
/// 根据架构契约 INV-009：快照与还原必须成对且原子。
public final class WindowManipulator: WindowManipulating {
    public init() {}

    public func setFrame(_ frame: CGRect, for window: WindowInfo) -> WindowOperationResult {
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var size = CGSize(width: frame.width, height: frame.height)

        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            return .failed(windowID: window.id, reason: "创建 position AXValue 失败")
        }
        let posResult = AXUIElementSetAttributeValue(
            window.axRef,
            kAXPositionAttribute as CFString,
            positionValue
        )

        guard posResult == .success else {
            return .failed(windowID: window.id, reason: "设置位置失败: \(posResult.rawValue)")
        }

        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .failed(windowID: window.id, reason: "创建 size AXValue 失败")
        }
        let sizeResult = AXUIElementSetAttributeValue(
            window.axRef,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard sizeResult == .success else {
            return .failed(windowID: window.id, reason: "设置大小失败: \(sizeResult.rawValue)")
        }

        return .success
    }

    public func focusedWindow(forPID pid: pid_t) -> WindowInfo? {
        let axApp = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard result == .success, let axValue = value else { return nil }

        // swiftlint:disable:next force_cast
        let axRef = axValue as! AXUIElement

        var position: CGPoint = .zero
        var posValue: AnyObject?
        if AXUIElementCopyAttributeValue(axRef, kAXPositionAttribute as CFString, &posValue) == .success,
           let axPos = posValue {
            // swiftlint:disable:next force_cast
            AXValueGetValue(axPos as! AXValue, .cgPoint, &position)
        }

        var size: CGSize = .zero
        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(axRef, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let axSize = sizeValue {
            // swiftlint:disable:next force_cast
            AXValueGetValue(axSize as! AXValue, .cgSize, &size)
        }

        let frame = CGRect(origin: position, size: size)

        return WindowInfo(
            id: 0,
            axRef: axRef,
            frame: frame,
            ownerPID: pid,
            title: ""
        )
    }

    public func snapshotWindows(_ windows: [WindowInfo]) -> [CGWindowID: CGRect] {
        var snapshot: [CGWindowID: CGRect] = [:]
        for window in windows {
            snapshot[window.id] = window.frame
        }
        return snapshot
    }

    public func restoreWindows(
        from snapshot: [CGWindowID: CGRect],
        windows: [WindowInfo]
    ) -> [WindowOperationResult] {
        windows.map { window in
            guard let originalFrame = snapshot[window.id] else {
                return .failed(windowID: window.id, reason: "无快照记录")
            }
            return setFrame(originalFrame, for: window)
        }
    }

    public func activateWindow(_ window: WindowInfo) -> WindowOperationResult {
        // F1: 通过 AX 组合调用激活窗口与所属 App
        let axApp = AXUIElementCreateApplication(window.ownerPID)
        let results = performAXActivationCalls(window: window, axApp: axApp)
        logAXActivationResults(window: window, results: results)

        // F1: AX 调用可能返回 success 但不改变 z-order（Finder 等部分 App 行为）
        // 用 CGEvent 模拟点击窗口标题栏中心，强制系统前置窗口
        simulateClickOnWindowTitlebar(window: window)

        let anySuccess = results.main == .success
            || results.focused == .success
            || results.raise == .success
            || results.frontmost == .success
            || results.focusWin == .success

        guard anySuccess else {
            let reason = "AX 激活全部失败: main=\(results.main.rawValue)" +
                " focused=\(results.focused.rawValue)" +
                " raise=\(results.raise.rawValue)" +
                " frontmost=\(results.frontmost.rawValue)" +
                " focusWin=\(results.focusWin.rawValue)"
            return .failed(windowID: window.id, reason: reason)
        }

        return .success
    }

    /// 用 CGEvent 模拟点击窗口中心，强制系统前置窗口
    ///
    /// AX 设置 kAXMainWindowAttribute 等可能不改变 z-order，
    /// CGEvent 模拟点击会让系统真正处理窗口前置。
    /// 点击位置：窗口中心区域（通过 AX 实时查询窗口当前位置）。
    ///
    /// 坐标系注意：
    /// - CGRect/NSRect 屏幕坐标系：左下角原点，Y 向上增长
    /// - CGEvent 鼠标坐标系：左上角原点，Y 向下增长
    /// 需要转换 Y 轴：CGEvent_Y = screenHeight - NSRect_Y
    private func simulateClickOnWindowTitlebar(window: WindowInfo) {
        // 通过 AX 实时查询窗口当前位置和大小（window.frame 可能是过时的枚举快照）
        guard let currentFrame = queryWindowFrame(window.axRef) else {
            let log = OSLog(subsystem: "com.tidy.windowmanagement", category: .pointsOfInterest)
            os_log("tidy.click FAIL wid=%llu ax-query-frame-failed",
                   log: log, type: .default, window.id)
            return
        }

        // 获取主屏高度用于 Y 轴转换
        let mainDisplayID = CGMainDisplayID()
        let screenHeight = CGDisplayPixelsHigh(mainDisplayID)

        // 点击窗口中心（CGEvent 坐标系：左上角原点）
        let clickCenter = CGPoint(
            x: currentFrame.midX,
            y: CGFloat(screenHeight) - currentFrame.midY
        )

        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: clickCenter,
            mouseButton: .left
        ),
            let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: clickCenter,
                mouseButton: .left
            ) else {
            let log = OSLog(subsystem: "com.tidy.windowmanagement", category: .pointsOfInterest)
            os_log("tidy.click FAIL wid=%llu cgEvent-create-failed",
                   log: log, type: .default, window.id)
            return
        }

        // 用 CGEvent.post(tap:) 发布事件到系统事件流
        mouseDown.post(tap: CGEventTapLocation.cgSessionEventTap)
        mouseUp.post(tap: CGEventTapLocation.cgSessionEventTap)

        let log = OSLog(subsystem: "com.tidy.windowmanagement", category: .pointsOfInterest)
        os_log("tidy.click wid=%llu x=%g y=%g screenH=%d frameMidY=%g pid=%d",
               log: log, type: .default,
               window.id,
               clickCenter.x, clickCenter.y,
               screenHeight, currentFrame.midY,
               window.ownerPID)
    }

    /// 通过 AX 查询窗口当前实际位置和大小
    private func queryWindowFrame(_ axRef: AXUIElement) -> CGRect? {
        var position: CGPoint = .zero
        var size: CGSize = .zero

        var posValue: AnyObject?
        if AXUIElementCopyAttributeValue(axRef, kAXPositionAttribute as CFString, &posValue) == .success,
           let axPos = posValue {
            // swiftlint:disable:next force_cast
            AXValueGetValue(axPos as! AXValue, .cgPoint, &position)
        } else {
            return nil
        }

        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(axRef, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let axSize = sizeValue {
            // swiftlint:disable:next force_cast
            AXValueGetValue(axSize as! AXValue, .cgSize, &size)
        } else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    /// AX 激活调用结果
    private struct AXActivationResults {
        let main: AXError
        let focused: AXError
        let raise: AXError
        let frontmost: AXError
        let focusWin: AXError
    }

    /// 执行 5 个 AX 激活调用，返回各调用结果
    private func performAXActivationCalls(
        window: WindowInfo,
        axApp: AXUIElement
    ) -> AXActivationResults {
        let main = AXUIElementSetAttributeValue(
            axApp, "AXMainWindow" as CFString, window.axRef
        )
        let focused = AXUIElementSetAttributeValue(
            axApp, "AXFocusedWindow" as CFString, window.axRef
        )
        let raise = AXUIElementSetAttributeValue(
            window.axRef, "AXRaise" as CFString, kCFBooleanTrue
        )
        let frontmost = AXUIElementSetAttributeValue(
            axApp, "AXFrontmost" as CFString, kCFBooleanTrue
        )
        let focusWin = AXUIElementSetAttributeValue(
            window.axRef, "AXFocused" as CFString, kCFBooleanTrue
        )
        return AXActivationResults(
            main: main, focused: focused, raise: raise,
            frontmost: frontmost, focusWin: focusWin
        )
    }

    /// 输出 AX 激活调用详细日志（诊断哪个 API 真正生效）
    private func logAXActivationResults(
        window: WindowInfo,
        results: AXActivationResults
    ) {
        let log = OSLog(subsystem: "com.tidy.windowmanagement", category: .pointsOfInterest)
        os_log(
            "tidy.ax-activate wid=%llu main=%d focused=%d raise=%d frontmost=%d focusWin=%d",
            log: log, type: .default,
            window.id,
            results.main.rawValue, results.focused.rawValue, results.raise.rawValue,
            results.frontmost.rawValue, results.focusWin.rawValue
        )
    }
}
