import AppKit

// MARK: – Toast type

enum ToastType {
    case text
    case barcode(String)   // symbology name
    case noContent
}

// MARK: – Controller

@MainActor
class ToastController {
    static let shared = ToastController()
    private var activeWindow: ToastWindow?
    private var hideTask: Task<Void, Never>?

    func show(_ type: ToastType, preview: String) {
        hideTask?.cancel()
        activeWindow?.orderOut(nil)

        let window = ToastWindow(type: type, preview: preview)
        activeWindow = window
        window.appear()

        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            window.disappear()
        }
    }
}

// MARK: – Window

class ToastWindow: NSWindow {
    private let toastView: ToastView

    init(type: ToastType, preview: String) {
        let w: CGFloat = 340, h: CGFloat = 66
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.visibleFrame
        // Start slightly below final position; appear() will slide it up
        let origin = CGPoint(x: sf.midX - w/2, y: sf.minY + 28 - 18)

        toastView = ToastView(type: type, preview: preview, frame: CGRect(x: 0, y: 0, width: w, height: h))

        super.init(contentRect: CGRect(origin: origin, size: CGSize(width: w, height: h)),
                   styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        ignoresMouseEvents = true
        alphaValue = 0
        collectionBehavior = [.canJoinAllSpaces, .transient]
        contentView = toastView
    }

    func appear() {
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(frame.offsetBy(dx: 0, dy: 18), display: true)
        }
    }

    func disappear() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }) { self.orderOut(nil) }
    }
}

// MARK: – View

class ToastView: NSView {
    init(type: ToastType, preview: String, frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        build(type: type, preview: preview)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(type: ToastType, preview: String) {
        // Heavy blur base
        let fx = NSVisualEffectView(frame: bounds)
        fx.material = .underWindowBackground   // strongest system blur
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 14
        fx.layer?.masksToBounds = true
        addSubview(fx)

        // Dark tint on top of the blur for contrast
        let tint = NSView(frame: bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.32).cgColor
        tint.layer?.cornerRadius = 14
        addSubview(tint)

        // Subtle border
        tint.layer?.borderWidth = 0.5
        tint.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor

        // Icon
        let (sym, color, title) = toastContent(type)
        let iconCfg = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let icon = NSImageView(frame: CGRect(x: 16, y: (bounds.height - 26)/2, width: 26, height: 26))
        icon.image = NSImage(systemSymbolName: sym, accessibilityDescription: nil)?
            .withSymbolConfiguration(iconCfg)
        icon.contentTintColor = color
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)

        let hasPreview = !preview.isEmpty && type != .noContent
        let titleY: CGFloat = hasPreview ? bounds.height/2 + 1 : (bounds.height - 17)/2

        // Title
        let titleLbl = makeLabel(title, font: .systemFont(ofSize: 13, weight: .semibold),
                                 color: .labelColor,
                                 frame: CGRect(x: 52, y: titleY, width: bounds.width - 68, height: 17))
        addSubview(titleLbl)

        // Preview
        if hasPreview {
            let short = String(preview.prefix(80)).replacingOccurrences(of: "\n", with: " ")
            let prevLbl = makeLabel(short, font: .systemFont(ofSize: 11),
                                    color: .secondaryLabelColor,
                                    frame: CGRect(x: 52, y: 10, width: bounds.width - 68, height: 14))
            addSubview(prevLbl)
        }
    }

    private func makeLabel(_ str: String, font: NSFont, color: NSColor, frame: CGRect) -> NSTextField {
        let f = NSTextField(frame: frame)
        f.stringValue = str
        f.font = font
        f.textColor = color
        f.isEditable = false
        f.isBordered = false
        f.backgroundColor = .clear
        f.cell?.truncatesLastVisibleLine = true
        f.cell?.lineBreakMode = .byTruncatingTail
        return f
    }

    private func toastContent(_ type: ToastType) -> (String, NSColor, String) {
        switch type {
        case .text:          return ("doc.on.clipboard.fill", .systemGreen,  "Text Copied")
        case .noContent:     return ("exclamationmark.circle", .systemOrange, "Nothing Found")
        case .barcode(let s):
            let isQR = s.lowercased().contains("qr")
            return (isQR ? "qrcode" : "barcode", .systemBlue, isQR ? "QR Code Copied" : "Barcode Copied")
        }
    }
}

extension ToastType: Equatable {
    static func == (lhs: ToastType, rhs: ToastType) -> Bool {
        switch (lhs, rhs) {
        case (.text, .text), (.noContent, .noContent): return true
        case (.barcode(let a), .barcode(let b)): return a == b
        default: return false
        }
    }
}
