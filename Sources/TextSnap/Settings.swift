import Foundation
import Carbon

class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key: String {
        case captureKeyCode         = "captureKeyCode"
        case captureCarbonModifiers = "captureCarbonModifiers"
        case hasRequestedScreenPermission
        case hasSetHotkey           = "hasSetHotkey"
    }

    // Default: Cmd+Shift+2  (keyCode 19 = '2')
    // Uses hasSetHotkey flag to distinguish "never set" from keyCode 0
    var captureKeyCode: Int {
        get {
            guard defaults.bool(forKey: Key.hasSetHotkey.rawValue) else { return 19 }
            return defaults.integer(forKey: Key.captureKeyCode.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Key.captureKeyCode.rawValue)
            defaults.set(true, forKey: Key.hasSetHotkey.rawValue)
        }
    }

    var captureCarbonModifiers: Int {
        get {
            guard defaults.bool(forKey: Key.hasSetHotkey.rawValue) else { return cmdKey | shiftKey }
            return defaults.integer(forKey: Key.captureCarbonModifiers.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.captureCarbonModifiers.rawValue) }
    }

    var hasRequestedScreenPermission: Bool {
        get { defaults.bool(forKey: Key.hasRequestedScreenPermission.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasRequestedScreenPermission.rawValue) }
    }

    var captureShortcutDisplay: String {
        var s = ""
        let mods = captureCarbonModifiers
        if mods & controlKey != 0 { s += "⌃" }
        if mods & optionKey  != 0 { s += "⌥" }
        if mods & shiftKey   != 0 { s += "⇧" }
        if mods & cmdKey     != 0 { s += "⌘" }
        return s + keyCodeName(captureKeyCode)
    }

    private func keyCodeName(_ code: Int) -> String {
        let map: [Int: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
            12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",
            22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"O",
            32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",
            43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"Space",51:"⌫",53:"⎋",
            123:"←",124:"→",125:"↓",126:"↑"
        ]
        return map[code] ?? "?"
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("com.textsnap.hotkeyChanged")
}
