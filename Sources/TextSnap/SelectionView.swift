import AppKit

class SelectionView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isDragging = false

    // Selection rect in AppKit view coords (origin bottom-left)
    private var selectionRect: CGRect {
        guard let s = startPoint, let c = currentPoint else { return .zero }
        return CGRect(
            x: min(s.x, c.x), y: min(s.y, c.y),
            width: abs(c.x - s.x), height: abs(c.y - s.y)
        )
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: – Mouse events

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        isDragging = false
        needsDisplay = true

        let rect = selectionRect
        guard rect.width > 5, rect.height > 5 else { onCancelled?(); return }
        onSelectionComplete?(rect)
    }

    // MARK: – Drawing

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSColor.black.withAlphaComponent(0.45)
        let rect = selectionRect

        if isDragging || (startPoint != nil && rect.width > 1 && rect.height > 1) {
            // Draw dim in four strips around the selection
            dim.setFill()
            [
                CGRect(x: 0, y: rect.maxY, width: bounds.width, height: bounds.maxY - rect.maxY),       // top
                CGRect(x: 0, y: 0,         width: bounds.width, height: rect.minY),                     // bottom
                CGRect(x: 0, y: rect.minY, width: rect.minX,    height: rect.height),                   // left
                CGRect(x: rect.maxX, y: rect.minY, width: bounds.maxX - rect.maxX, height: rect.height) // right
            ].forEach { NSBezierPath(rect: $0).fill() }

            // Selection border
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.75, dy: 0.75))
            border.lineWidth = 1.5
            NSColor.white.setStroke()
            border.stroke()

            drawHandles(in: rect)
            drawSizeLabel(for: rect)
        } else {
            // No selection yet – full dim + hint
            dim.setFill()
            NSBezierPath(rect: bounds).fill()
            drawHint()
        }
    }

    private func drawHandles(in rect: CGRect) {
        let r: CGFloat = 4
        let corners: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        NSColor.white.setFill()
        corners.forEach { NSBezierPath(ovalIn: CGRect(x: $0.x - r, y: $0.y - r, width: r*2, height: r*2)).fill() }
    }

    private func drawSizeLabel(for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let pad: CGFloat = 5
        let sz = (text as NSString).size(withAttributes: attrs)
        let bx = CGRect(x: rect.midX - sz.width/2 - pad, y: rect.minY - sz.height - pad*2 - 2,
                        width: sz.width + pad*2, height: sz.height + pad)
        let bg = NSBezierPath(roundedRect: bx, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.72).setFill()
        bg.fill()
        (text as NSString).draw(at: CGPoint(x: bx.minX + pad, y: bx.minY + pad/2), withAttributes: attrs)
    }

    private func drawHint() {
        let text = "Drag to select an area"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75)
        ]
        let pad: CGFloat = 6
        let sz = (text as NSString).size(withAttributes: attrs)
        let margin: CGFloat = 20
        let bx = CGRect(x: margin, y: margin, width: sz.width + pad * 2, height: sz.height + pad)
        let bg = NSBezierPath(roundedRect: bx, xRadius: 5, yRadius: 5)
        NSColor.black.withAlphaComponent(0.55).setFill()
        bg.fill()
        (text as NSString).draw(at: CGPoint(x: bx.minX + pad, y: bx.minY + pad / 2), withAttributes: attrs)
    }
}
