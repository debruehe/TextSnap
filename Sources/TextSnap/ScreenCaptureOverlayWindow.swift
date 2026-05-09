import AppKit

class ScreenCaptureOverlayWindow: NSWindow {
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancelled: (() -> Void)?

    private let targetScreen: NSScreen
    private let selectionView: SelectionView
    private var keyMonitor: Any?

    init(screen: NSScreen, backgroundImage: CGImage) {
        self.targetScreen = screen
        let contentSize = screen.frame.size
        let contentFrame = CGRect(origin: .zero, size: contentSize)
        self.selectionView = SelectionView(frame: contentFrame)
        self.selectionView.backgroundImage = backgroundImage

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
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

        // Handle ESC before the window becomes key (events go to the previous app)
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.onCancelled?() } // ESC
        }
    }

    deinit {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancelled?()
            return
        }
        selectionView.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        selectionView.keyUp(with: event)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? CGMainDisplayID()
    }
}
