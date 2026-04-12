import AppKit

class ScreenCaptureOverlayWindow: NSWindow {
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancelled: (() -> Void)?

    private let targetScreen: NSScreen
    private let selectionView: SelectionView

    init(screen: NSScreen) {
        self.targetScreen = screen
        let contentSize = screen.frame.size
        let contentFrame = CGRect(origin: .zero, size: contentSize)
        self.selectionView = SelectionView(frame: contentFrame)

        // Use the designated init (4-arg); pass screen.frame so the window
        // lands on the correct display in global screen coordinates.
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelKey.screenSaverWindow.rawValue) + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSView(frame: contentFrame)
        container.wantsLayer = true
        contentView = container
        container.addSubview(selectionView)

        selectionView.onSelectionComplete = { [weak self] rect in
            guard let self else { return }
            self.onSelectionComplete?(rect, self.targetScreen)
        }
        selectionView.onCancelled = { [weak self] in
            self?.onCancelled?()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancelled?() } // ESC
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? CGMainDisplayID()
    }
}
