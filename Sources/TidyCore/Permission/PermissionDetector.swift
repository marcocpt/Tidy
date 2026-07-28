import ApplicationServices
import Combine
import Foundation

/// AX 权限状态
public enum AccessibilityPermissionStatus: Sendable, Equatable {
    case granted
    case denied
}

/// AX 权限检测与变化监听
///
/// 职责：检测辅助功能权限授权状态；监听授权状态变化（不轮询）。
/// 不负责：引导用户授权（F0 的职责）；不决定权限缺失时是否退出编排。
///
/// 根据架构契约 INV-010：权限缺失时不得执行窗口操作。
public final class PermissionDetector: ObservableObject {
    /// 当前权限状态
    @Published public private(set) var status: AccessibilityPermissionStatus

    /// 权限状态变化通知（Combine 发布者）
    public var statusPublisher: AnyPublisher<AccessibilityPermissionStatus, Never> {
        $status.eraseToAnyPublisher()
    }

    private var checkTimer: Timer?

    public init() {
        let currentStatus = Self.checkAXPermission()
        self.status = currentStatus
    }

    deinit {
        stopMonitoring()
    }

    /// 查询当前 AX 权限状态
    public static func checkAXPermission() -> AccessibilityPermissionStatus {
        AXIsProcessTrustedWithOptions(nil) ? .granted : .denied
    }

    /// 开始监听权限状态变化
    ///
    /// 使用定时轮询方式检测变化（macOS 无直接回调）。
    /// 间隔 1 秒，仅在状态实际变化时发布通知。
    public func startMonitoring(interval: TimeInterval = 1.0) {
        stopMonitoring()

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            let newStatus = Self.checkAXPermission()
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

    /// 请求权限（打开系统设置）
    public func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
