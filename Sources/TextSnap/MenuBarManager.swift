import AppKit

class MenuBarManager {
    private var statusItem: NSStatusItem!
    private let captureController: CaptureController

    init(captureController: CaptureController) {
        self.captureController = captureController
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "TextSnap")
            btn.image?.isTemplate = true
        }

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture Text / QR Code", action: #selector(startCapture), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit TextSnap", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func startCapture() { captureController.startCapture() }
    @objc func openPrefs() {
        PreferencesWindowController.shared.showWindow(nil)
        NSApp.activate()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
