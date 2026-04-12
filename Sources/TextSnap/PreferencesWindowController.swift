import AppKit
import Carbon
import ServiceManagement

class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private var hotkeyButton: NSButton!
    private var loginCheckbox: NSButton!
    private var recordingHotkey = false
    private var keyMonitor: Any?

    init() {
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 400, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        win.title = "TextSnap Preferences"
        win.center()
        super.init(window: win)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // ── Launch at Login ──────────────────────────────────────────────
        let loginSection = label("General",
                                 font: .systemFont(ofSize: 13, weight: .semibold),
                                 frame: CGRect(x: 20, y: 222, width: 360, height: 18))
        cv.addSubview(loginSection)

        loginCheckbox = NSButton(checkboxWithTitle: "Launch TextSnap at login",
                                 target: self, action: #selector(toggleLaunchAtLogin))
        loginCheckbox.frame = CGRect(x: 20, y: 196, width: 300, height: 20)
        loginCheckbox.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        cv.addSubview(loginCheckbox)

        let sep1 = NSBox(frame: CGRect(x: 20, y: 180, width: 360, height: 1))
        sep1.boxType = .separator
        cv.addSubview(sep1)

        // ── Keyboard Shortcut ────────────────────────────────────────────
        let sectionLabel = label("Keyboard Shortcut",
                                 font: .systemFont(ofSize: 13, weight: .semibold),
                                 frame: CGRect(x: 20, y: 156, width: 360, height: 18))
        cv.addSubview(sectionLabel)

        let descLabel = label("Press this shortcut to start a screen capture.",
                              font: .systemFont(ofSize: 11), color: .secondaryLabelColor,
                              frame: CGRect(x: 20, y: 136, width: 360, height: 16))
        cv.addSubview(descLabel)

        hotkeyButton = NSButton(frame: CGRect(x: 20, y: 96, width: 210, height: 30))
        hotkeyButton.bezelStyle = .rounded
        hotkeyButton.target = self
        hotkeyButton.action = #selector(beginRecording)
        refreshHotkeyTitle()
        cv.addSubview(hotkeyButton)

        let resetBtn = NSButton(frame: CGRect(x: 238, y: 96, width: 80, height: 30))
        resetBtn.title = "Reset"
        resetBtn.bezelStyle = .rounded
        resetBtn.target = self
        resetBtn.action = #selector(resetHotkey)
        cv.addSubview(resetBtn)

        let sep2 = NSBox(frame: CGRect(x: 20, y: 80, width: 360, height: 1))
        sep2.boxType = .separator
        cv.addSubview(sep2)

        // ── Permissions ──────────────────────────────────────────────────
        let permLabel = label("TextSnap requires Screen Recording permission.",
                              font: .systemFont(ofSize: 11), color: .secondaryLabelColor,
                              frame: CGRect(x: 20, y: 50, width: 360, height: 16))
        cv.addSubview(permLabel)

        let permBtn = NSButton(frame: CGRect(x: 20, y: 26, width: 230, height: 18))
        permBtn.title = "Open Privacy & Security Settings →"
        permBtn.bezelStyle = .inline
        permBtn.isBordered = false
        permBtn.contentTintColor = .systemBlue
        permBtn.font = .systemFont(ofSize: 11)
        permBtn.target = self
        permBtn.action = #selector(openPrivacy)
        cv.addSubview(permBtn)
    }

    // MARK: – Actions

    @objc func toggleLaunchAtLogin() {
        do {
            if loginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert checkbox on failure
            loginCheckbox.state = (loginCheckbox.state == .on) ? .off : .on
        }
    }

    @objc func beginRecording() {
        guard !recordingHotkey else { return }
        recordingHotkey = true
        hotkeyButton.title = "Press shortcut…"

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] (event: NSEvent) -> NSEvent? in
            guard let self, self.recordingHotkey else { return event }
            let mods = event.modifierFlags.carbonFlags
            guard mods != 0 else { return nil }
            Settings.shared.captureKeyCode = Int(event.keyCode)
            Settings.shared.captureCarbonModifiers = mods
            self.recordingHotkey = false
            self.refreshHotkeyTitle()
            if let m = self.keyMonitor { NSEvent.removeMonitor(m); self.keyMonitor = nil }
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
            return nil
        }
    }

    @objc func resetHotkey() {
        Settings.shared.captureKeyCode = 19
        Settings.shared.captureCarbonModifiers = cmdKey | shiftKey
        refreshHotkeyTitle()
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
    }

    @objc func openPrivacy() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        )
    }

    // MARK: – Helpers

    private func refreshHotkeyTitle() {
        hotkeyButton.title = hotkeyString(
            keyCode: Settings.shared.captureKeyCode,
            carbonMods: Settings.shared.captureCarbonModifiers
        )
    }

    private func hotkeyString(keyCode: Int, carbonMods: Int) -> String {
        var s = ""
        if carbonMods & controlKey != 0 { s += "⌃" }
        if carbonMods & optionKey  != 0 { s += "⌥" }
        if carbonMods & shiftKey   != 0 { s += "⇧" }
        if carbonMods & cmdKey     != 0 { s += "⌘" }
        return s + (keyCodeName[keyCode] ?? "?")
    }

    private let keyCodeName: [Int: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
        12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",
        22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"O",
        32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",
        43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"Space",51:"⌫",53:"⎋",
        123:"←",124:"→",125:"↓",126:"↑"
    ]

    private func label(_ str: String, font: NSFont, color: NSColor = .labelColor, frame: CGRect) -> NSTextField {
        let f = NSTextField(labelWithString: str)
        f.frame = frame
        f.font = font
        f.textColor = color
        return f
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: Int {
        var r = 0
        if contains(.command) { r |= cmdKey }
        if contains(.option)  { r |= optionKey }
        if contains(.shift)   { r |= shiftKey }
        if contains(.control) { r |= controlKey }
        return r
    }
}
