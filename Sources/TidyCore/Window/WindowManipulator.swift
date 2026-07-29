import ApplicationServices
import Foundation

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

        let axRef = axValue as! AXUIElement

        var position: CGPoint = .zero
        var posValue: AnyObject?
        if AXUIElementCopyAttributeValue(axRef, kAXPositionAttribute as CFString, &posValue) == .success,
           let axPos = posValue {
            AXValueGetValue(axPos as! AXValue, .cgPoint, &position)
        }

        var size: CGSize = .zero
        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(axRef, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let axSize = sizeValue {
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
}
