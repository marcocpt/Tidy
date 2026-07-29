import ApplicationServices
import Combine
import Foundation

/// Input Monitoring 权限状态
public enum InputMonitoringPermissionStatus: Sendable, Equatable {
    case granted
    case denied
    case notRequired
}

/// Input Monitoring 权限检测与变化监听
///
/// 职责：检测输入监控权限授权状态；监听授权状态变化。
/// 不负责：引导用户授权（F0 PermissionGuideWindow 的职责）；
/// 不负责打开系统设置（需要 AppKit，属于 UI/App 层）。
///
/// 实现方式：尝试创建 CGEventTap，若成功则权限已授予。
///
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
public final class InputMonitoringDetector: ObservableObject {
    /// 当前权限状态
    @Published public private(set) var status: InputMonitoringPermissionStatus

    /// 权限状态变化通知
    public var statusPublisher: AnyPublisher<InputMonitoringPermissionStatus, Never> {
        $status.eraseToAnyPublisher()
    }

    private var checkTimer: Timer?

    public init() {
        let currentStatus = Self.checkPermission()
        self.status = currentStatus
    }

    deinit {
        stopMonitoring()
    }

    /// 查询当前 Input Monitoring 权限状态
    ///
    /// 通过尝试创建 CGEventTap 判断权限是否已授予。
    /// 创建后立即释放，不影响正常 EventTap 使用。
    public static func checkPermission() -> InputMonitoringPermissionStatus {
        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let testTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )

        if let tap = testTap {
            // 创建成功，权限已授予。立即释放测试 tap。
            CGEvent.tapEnable(tap: tap, enable: false)
            return .granted
        }

        // 创建失败，判断是否因为权限缺失
        // macOS 13+ 强制要求 Input Monitoring 权限
        // macOS 12 可能不需要
        if #available(macOS 13.0, *) {
            return .denied
        } else {
            return .notRequired
        }
    }

    /// 开始监听权限状态变化
    ///
    /// 使用定时轮询方式检测变化。
    /// 间隔 1 秒，仅在状态实际变化时发布通知。
    public func startMonitoring(interval: TimeInterval = 1.0) {
        stopMonitoring()

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            let newStatus = Self.checkPermission()
            if newStatus != self.status {
                self.status = newStatus
            }
        }
    }

    /// 停止监听
    public func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
