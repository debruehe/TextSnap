import Foundation
import Carbon

class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key: String {
        case captureKeyCode         = "captureKeyCode"
        case captureCarbonModifiers = "captureCarbonModifiers"
        case hasRequestedScreenPermission
    }

    // Default: Cmd+Shift+2  (keyCode 19 = '2')
    var captureKeyCode: Int {
        get {
            let v = defaults.integer(forKey: Key.captureKeyCode.rawValue)
            return v == 0 ? 19 : v
        }
        set { defaults.set(newValue, forKey: Key.captureKeyCode.rawValue) }
    }

    var captureCarbonModifiers: Int {
        get {
            let v = defaults.integer(forKey: Key.captureCarbonModifiers.rawValue)
            return v == 0 ? (cmdKey | shiftKey) : v
        }
        set { defaults.set(newValue, forKey: Key.captureCarbonModifiers.rawValue) }
    }

    var hasRequestedScreenPermission: Bool {
        get { defaults.bool(forKey: Key.hasRequestedScreenPermission.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasRequestedScreenPermission.rawValue) }
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("com.textsnap.hotkeyChanged")
}
