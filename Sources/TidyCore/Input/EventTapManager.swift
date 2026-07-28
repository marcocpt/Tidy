import CoreGraphics
import Foundation

// MARK: - 事件拦截协议

/// CGEventTap 管理协议
///
/// 根据架构契约 INV-007：输入拦截仅在编排选择阶段启用。
/// 根据架构契约 INV-008：跨组件通信通过协议。
public protocol EventTapManaging {
    /// 启动事件拦截
    ///
    /// handler 返回 true 消费事件，false 放行，nil 表示处理出错。
    /// - Returns: 启动是否成功
    @discardableResult
    func startTap(handler: @escaping (CGEvent) -> Bool?) -> Bool

    /// 停止事件拦截
    func stopTap()

    /// 事件拦截是否正在工作
    var isActive: Bool { get }
}

// MARK: - 事件拦截错误

/// EventTap 创建或启用失败
public enum EventTapError: Error, Equatable {
    /// CGEventTap 创建返回 nil
    case tapCreationFailed
    /// CGEventTap 无法启用
    case tapEnableFailed
}

// MARK: - 事件拦截管理器

/// CGEventTap 管理器
///
/// 职责：创建/启用/禁用 CGEventTap；分发键盘事件给调用方 handler。
/// 不负责：不决定"按键后做什么"（编排控制器的职责）；不渲染 UI。
///
/// P0 探针阶段使用 kCGEventTapOptionListenOnly 确保安全。
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
/// 根据架构契约 INV-007：输入拦截仅在编排选择阶段启用。
public final class EventTapManager: EventTapManaging {
    /// 事件拦截是否正在工作
    public var isActive: Bool {
        guard let tap = machPort else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    /// 最近一次拦截错误（系统禁用 tap 后存储）
    public private(set) var lastError: EventTapError?

    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// 回调分发表：tapID → handler，供 C 回调查找
    static var handlerMap: [UInt8: (CGEvent) -> Bool?] = [:]
    private static var nextTapID: UInt8 = 0
    private var tapID: UInt8 = 0

    public init() {}

    deinit {
        stopTap()
    }

    /// 启动事件拦截
    @discardableResult
    public func startTap(handler: @escaping (CGEvent) -> Bool?) -> Bool {
        stopTap()
        lastError = nil

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tapID = Self.allocateTapID() else { return false }
        self.tapID = tapID
        Self.handlerMap[tapID] = handler

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(bitPattern: UInt(tapID))
        )

        guard let createdTap = tap else {
            Self.handlerMap.removeValue(forKey: tapID)
            lastError = .tapCreationFailed
            return false
        }

        return activateTap(createdTap)
    }

    /// 停止事件拦截
    public func stopTap() {
        guard let tap = machPort else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        cleanupTapResources()
    }

    /// 处理系统禁用事件拦截的情况
    ///
    /// 系统可能因超时禁用 CGEventTap，此方法尝试重新启用。
    /// 重新启用失败时存储错误状态。
    public func handleTapDisabled() {
        guard let tap = machPort else { return }

        CGEvent.tapEnable(tap: tap, enable: true)

        if !CGEvent.tapIsEnabled(tap: tap) {
            cleanupTapResources()
            lastError = .tapEnableFailed
        }
    }

    // MARK: - 私有方法

    private func activateTap(_ tap: CFMachPort) -> Bool {
        machPort = tap

        let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            tap,
            0
        )
        guard let createdSource = source else {
            Self.handlerMap.removeValue(forKey: tapID)
            self.machPort = nil
            lastError = .tapCreationFailed
            return false
        }

        runLoopSource = createdSource
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            createdSource,
            .commonModes
        )
        CGEvent.tapEnable(tap: tap, enable: true)

        if !CGEvent.tapIsEnabled(tap: tap) {
            cleanupTapResources()
            lastError = .tapEnableFailed
            return false
        }

        return true
    }

    private func cleanupTapResources() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                source,
                .commonModes
            )
        }
        if let tap = machPort {
            CFMachPortInvalidate(tap)
        }
        Self.handlerMap.removeValue(forKey: tapID)
        runLoopSource = nil
        machPort = nil
    }

    private static func allocateTapID() -> UInt8? {
        guard nextTapID < UInt8.max else { return nil }
        defer { nextTapID &+= 1 }
        return nextTapID
    }
}

// MARK: - C 回调

private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let rawValue = userInfo.map { UInt(bitPattern: $0) } ?? 0
    let tapKey = UInt8(truncatingIfNeeded: rawValue)

    guard let handler = EventTapManager.handlerMap[tapKey] else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let result = handler(event)
    if let shouldConsume = result, shouldConsume {
        return nil
    }
    return Unmanaged.passUnretained(event)
}
