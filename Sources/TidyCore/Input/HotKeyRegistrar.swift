import Carbon
import CoreFoundation
import Foundation

// MARK: - 热键配置

/// 全局热键配置
///
/// 封装 Carbon 键码与修饰符标志，用于 `HotkeyRegistrating` 注册。
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
public struct HotkeyConfig: Equatable {
    /// Carbon 键码（参见 Events.h 中 vkCode 定义）
    public let keyCode: UInt32
    /// Carbon 修饰符标志（cmdKey / shiftKey / optionKey / controlKey 等）
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

// MARK: - 热键注册协议

/// 全局热键注册协议
///
/// 根据架构契约 INV-008：跨组件通信通过协议。
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
public protocol HotkeyRegistrating {
    /// 注册全局热键，成功返回 true
    func register(hotkey: HotkeyConfig, handler: @escaping () -> Void) -> Bool
    /// 注销已注册的热键
    func unregister()
}

// MARK: - Carbon 回调分发表

/// Carbon 回调无法捕获 Swift 上下文，使用全局分发表桥接。
private enum HotkeyDispatch {
    /// hotkeyID → handler
    static var handlerTable: [UInt32: () -> Void] = [:]
    /// "Tidy" 四字符签名
    static let signature: FourCharCode = {
        let chars: [UInt8] = [0x54, 0x69, 0x64, 0x79] // "Tidy"
        return FourCharCode(chars[0]) << 24
            | FourCharCode(chars[1]) << 16
            | FourCharCode(chars[2]) << 8
            | FourCharCode(chars[3])
    }()
}

// MARK: - Carbon 全局回调

private func tidyHotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr, hotKeyID.signature == HotkeyDispatch.signature else {
        return OSStatus(eventNotHandledErr)
    }

    if let handler = HotkeyDispatch.handlerTable[hotKeyID.id] {
        handler()
    }

    return noErr
}

// MARK: - 热键注册器

/// Carbon 全局热键注册器
///
/// 职责：通过 Carbon `RegisterEventHotKey` 注册系统级全局热键；
/// 通过 `UnregisterEventHotKey` 注销；将 Carbon 回调桥接到 Swift 闭包。
/// 不负责：不决定热键键码（由调用方配置）；不处理 UI 响应。
///
/// 根据架构契约 INV-001：核心逻辑层永不依赖 UI 框架。
/// 根据架构契约 INV-008：跨组件通信通过协议。
public final class HotkeyRegistrar: HotkeyRegistrating {
    /// 下一个可用热键 ID（递增）
    private static var nextID: UInt32 = 1
    /// 共享 Carbon EventHandlerRef，仅安装一次
    private static var eventHandlerRef: EventHandlerRef?
    /// Carbon EventHotKeyRef，注销时需要
    private var hotKeyRef: EventHotKeyRef?
    /// 当前注册分配的 ID，用于注销时清理分发表
    private var assignedID: UInt32?

    public init() {}

    deinit {
        unregister()
    }

    /// 注册全局热键
    ///
    /// - Parameters:
    ///   - hotkey: 热键配置（键码 + 修饰符）
    ///   - handler: 热键按下时的回调闭包
    /// - Returns: 注册成功返回 true，失败返回 false
    public func register(hotkey: HotkeyConfig, handler: @escaping () -> Void) -> Bool {
        unregister()

        let id = Self.nextID
        Self.nextID += 1

        let hotKeyID = EventHotKeyID(
            signature: HotkeyDispatch.signature,
            id: id
        )

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, ref != nil else { return false }

        hotKeyRef = ref
        assignedID = id
        HotkeyDispatch.handlerTable[id] = handler

        installEventHandlerIfNeeded()

        return true
    }

    /// 注销已注册的热键
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let id = assignedID {
            HotkeyDispatch.handlerTable.removeValue(forKey: id)
            assignedID = nil
        }
    }

    /// 确保碳事件处理器只安装一次
    private func installEventHandlerIfNeeded() {
        guard Self.eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            tidyHotKeyEventHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        if status == noErr {
            Self.eventHandlerRef = handlerRef
        }
    }
}
