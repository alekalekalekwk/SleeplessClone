import Foundation
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    private enum Keys {
        static let durationMinutes = "durationMinutes"
        static let stopAtBatteryPercent = "stopAtBatteryPercent"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }

    private let defaults = UserDefaults.standard

    @Published var durationMinutes: Int? {
        didSet {
            if let duration = durationMinutes {
                defaults.set(duration, forKey: Keys.durationMinutes)
            } else {
                defaults.set(-1, forKey: Keys.durationMinutes)
            }
        }
    }

    @Published var stopAtBatteryPercent: Int {
        didSet {
            defaults.set(stopAtBatteryPercent, forKey: Keys.stopAtBatteryPercent)
        }
    }

    @Published var hotkeyKeyCode: UInt32 {
        didSet {
            defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode)
        }
    }

    @Published var hotkeyModifiers: UInt32 {
        didSet {
            defaults.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers)
        }
    }

    private init() {
        if defaults.object(forKey: Keys.durationMinutes) == nil {
            self.durationMinutes = 120
        } else {
            let val = defaults.integer(forKey: Keys.durationMinutes)
            self.durationMinutes = (val < 0) ? nil : val
        }

        if defaults.object(forKey: Keys.stopAtBatteryPercent) == nil {
            self.stopAtBatteryPercent = 20
        } else {
            let val = defaults.integer(forKey: Keys.stopAtBatteryPercent)
            self.stopAtBatteryPercent = (val >= 10 && val <= 80) ? val : 20
        }

        if defaults.object(forKey: Keys.hotkeyKeyCode) == nil {
            self.hotkeyKeyCode = UInt32(kVK_ANSI_P)
        } else {
            self.hotkeyKeyCode = UInt32(defaults.integer(forKey: Keys.hotkeyKeyCode))
        }

        if defaults.object(forKey: Keys.hotkeyModifiers) == nil {
            self.hotkeyModifiers = UInt32(controlKey | optionKey | cmdKey)
        } else {
            self.hotkeyModifiers = UInt32(defaults.integer(forKey: Keys.hotkeyModifiers))
        }
    }

    var hotkeyDisplayString: String {
        Settings.formatShortcut(keyCode: hotkeyKeyCode, carbonModifiers: hotkeyModifiers)
    }

    static func formatShortcut(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var result = ""
        if (carbonModifiers & UInt32(controlKey)) != 0 { result += "⌃" }
        if (carbonModifiers & UInt32(optionKey)) != 0 { result += "⌥" }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { result += "⇧" }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { result += "⌘" }
        result += keyString(for: keyCode)
        return result
    }

    static func keyString(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key"
        }
    }
}
