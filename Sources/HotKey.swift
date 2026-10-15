import Carbon.HIToolbox
import Foundation

private let kHotKeySignature: OSType = 0x534C5043 // "SLPC"
@MainActor private var globalHotKeyHandler: HotKeyManager?

@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotKey: (() -> Void)?

    static let shared = HotKeyManager()

    private init() {
        globalHotKeyHandler = self
    }

    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        unregister()

        let hotKeyID = EventHotKeyID(signature: kHotKeySignature, id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        guard status == noErr else { return false }

        let regStatus = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if regStatus != noErr {
            if let handler = eventHandlerRef {
                RemoveEventHandler(handler)
                eventHandlerRef = nil
            }
            return false
        }
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}

private func hotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    Task { @MainActor in
        globalHotKeyHandler?.onHotKey?()
    }
    return noErr
}
