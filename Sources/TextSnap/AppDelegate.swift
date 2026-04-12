import AppKit
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager!
    var captureController: CaptureController!
    var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        captureController = CaptureController()
        menuBarManager = MenuBarManager(captureController: captureController)
        hotkeyManager = HotkeyManager()

        registerHotkeys()

        NotificationCenter.default.addObserver(
            self, selector: #selector(hotkeyChanged),
            name: .hotkeyChanged, object: nil
        )

        // Trigger Screen Recording permission dialog on first launch
        if !Settings.shared.hasRequestedScreenPermission {
            Settings.shared.hasRequestedScreenPermission = true
            Task { _ = try? await SCShareableContent.current }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAll()
    }

    func registerHotkeys() {
        hotkeyManager.registerHotkey(
            id: 1,
            keyCode: UInt32(Settings.shared.captureKeyCode),
            carbonModifiers: UInt32(Settings.shared.captureCarbonModifiers)
        ) { [weak self] in
            DispatchQueue.main.async { self?.captureController.startCapture() }
        }
    }

    @objc func hotkeyChanged() {
        hotkeyManager.unregisterAll()
        registerHotkeys()
    }
}
