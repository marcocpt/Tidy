import ApplicationServices
import Foundation

/// 窗口信息
///
/// 封装 CGWindowID 和 AXUIElement 引用，以及原始 frame。
/// 根据架构契约 INV-008：跨组件通信通过协议。
public struct WindowInfo: Identifiable, Equatable {
    public let id: CGWindowID
    public let axRef: AXUIElement
    public var frame: CGRect
    public let ownerPID: pid_t
    public let title: String

    public init(id: CGWindowID, axRef: AXUIElement, frame: CGRect, ownerPID: pid_t, title: String) {
        self.id = id
        self.axRef = axRef
        self.frame = frame
        self.ownerPID = ownerPID
        self.title = title
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// 窗口枚举协议
///
/// 根据架构契约 INV-008：跨组件通信通过协议。
public protocol WindowEnumerating {
    /// 枚举前台 App 在当前 Space 上的所有可见窗口
    func enumerateVisibleWindows(forPID pid: pid_t) -> [WindowInfo]
}

/// 窗口枚举器
///
/// 职责：枚举前台 App 在当前 Space 上的所有可见窗口；将 CGWindowList 结果与 AX 窗口引用按 frame 匹配。
/// 不负责：不操作窗口位置（WindowManipulator 的职责）；不判断权限（PermissionDetector 的职责）。
/// 不负责前台 PID 获取（需要 AppKit，属于 UI/App 层）。
///
/// 根据架构契约 INV-005：窗口操作仅通过辅助功能公开接口。
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
public final class WindowEnumerator: WindowEnumerating {
    public init() {}

    public func enumerateVisibleWindows(forPID pid: pid_t) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            .optionOnScreenOnly,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let axApp = AXUIElementCreateApplication(pid)
        let axWindows = axApp.windowsValue ?? []

        return windowList.compactMap { dict -> WindowInfo? in
            self.parseWindowInfo(from: dict, pid: pid, axWindows: axWindows)
        }
    }

    private func parseWindowInfo(
        from dict: [String: Any],
        pid: pid_t,
        axWindows: [AXUIElement]
    ) -> WindowInfo? {
        guard let windowPID = dict[kCGWindowOwnerPID as String] as? pid_t,
              windowPID == pid,
              let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
              let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat],
              let layer = dict[kCGWindowLayer as String] as? Int,
              layer == 0
        else { return nil }

        let frame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        guard frame.width > 0, frame.height > 0 else { return nil }

        let title = dict[kCGWindowName as String] as? String ?? ""
        let axRef = matchAXWindow(from: axWindows, frame: frame)

        return WindowInfo(
            id: windowID,
            axRef: axRef,
            frame: frame,
            ownerPID: pid,
            title: title
        )
    }

    private func matchAXWindow(from axWindows: [AXUIElement], frame: CGRect) -> AXUIElement {
        // CGWindowList 和 AX 都使用顶部原点全局坐标系（Y 向下），坐标值相同。
        // 通过 frame 近似匹配（容差 2 points）关联 CGWindowID 与 AXUIElement。
        return axWindows.first { axWindow in
            guard let position = axWindow.positionValue,
                  let size = axWindow.sizeValue
            else { return false }
            let axFrame = CGRect(origin: position, size: size)
            return abs(axFrame.origin.x - frame.origin.x) < 2 &&
                abs(axFrame.origin.y - frame.origin.y) < 2 &&
                abs(axFrame.width - frame.width) < 2 &&
                abs(axFrame.height - frame.height) < 2
        } ?? AXUIElementCreateSystemWide()
    }
}

// MARK: - AXUIElement 辅助扩展

private extension AXUIElement {
    var windowsValue: [AXUIElement]? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            self,
            kAXWindowsAttribute as CFString,
            &value
        )
        guard result == .success else { return nil }
        return value as? [AXUIElement]
    }

    var positionValue: CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            self,
            kAXPositionAttribute as CFString,
            &value
        )
        guard result == .success, let axValue = value else { return nil }
        // AXUIElementCopyAttributeValue 返回 AXValue 对象，不是直接 CGPoint
        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    var sizeValue: CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            self,
            kAXSizeAttribute as CFString,
            &value
        )
        guard result == .success, let axValue = value else { return nil }
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
