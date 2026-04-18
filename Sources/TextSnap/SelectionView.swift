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
                CGRect(x: 0, y: rect.maxY, width: bounds.width, height: bounds.maxY - rect.maxY),
                CGRect(x: 0, y: 0,         width: bounds.width, height: rect.minY),
                CGRect(x: 0, y: rect.minY, width: rect.minX,    height: rect.height),
                CGRect(x: rect.maxX, y: rect.minY, width: bounds.maxX - rect.maxX, height: rect.height)
            ].forEach { NSBezierPath(rect: $0).fill() }

            // Selection border
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.75, dy: 0.75))
            border.lineWidth = 1.5
            NSColor.white.setStroke()
            border.stroke()

            drawCrosshairs(at: currentPoint!, excluding: rect)
            drawHandles(in: rect)
            drawSizeLabel(for: rect)
            drawEscHint()
        } else {
            // No selection yet – full dim + hint
            dim.setFill()
            NSBezierPath(rect: bounds).fill()
            drawHint()
            drawEscHint()
            if let cp = currentPoint {
                drawCrosshairLines(at: cp)
            }
        }
    }

    // MARK: – Crosshair guide lines (shown during idle and drag)

    private func drawCrosshairLines(at point: NSPoint) {
        let dashes: [CGFloat] = [4, 4]
        let path = NSBezierPath()
        path.lineWidth = 0.5

        // Vertical line
        path.move(to: CGPoint(x: point.x, y: 0))
        path.line(to: CGPoint(x: point.x, y: bounds.height))

        // Horizontal line
        path.move(to: CGPoint(x: 0, y: point.y))
        path.line(to: CGPoint(x: bounds.width, y: point.y))

        path.setLineDash(dashes, count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.35).setStroke()
        path.stroke()
    }

    private func drawCrosshairs(at point: NSPoint, excluding rect: CGRect) {
        let path = NSBezierPath()
        path.lineWidth = 0.5

        // Vertical line above and below selection
        if point.y > rect.maxY {
            path.move(to: CGPoint(x: point.x, y: rect.maxY))
            path.line(to: CGPoint(x: point.x, y: min(point.y, bounds.height)))
        }
        if point.y < rect.minY {
            path.move(to: CGPoint(x: point.x, y: max(point.y, 0)))
            path.line(to: CGPoint(x: point.x, y: rect.minY))
        }

        // Horizontal line left and right of selection
        if point.x > rect.maxX {
            path.move(to: CGPoint(x: rect.maxX, y: point.y))
            path.line(to: CGPoint(x: min(point.x, bounds.width), y: point.y))
        }
        if point.x < rect.minX {
            path.move(to: CGPoint(x: max(point.x, 0), y: point.y))
            path.line(to: CGPoint(x: rect.minX, y: point.y))
        }

        NSColor.white.withAlphaComponent(0.25).setStroke()
        path.stroke()
    }

    // MARK: – Corner handles

    private func drawHandles(in rect: CGRect) {
        let r: CGFloat = 4
        let corners: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        NSColor.white.setFill()
        corners.forEach { NSBezierPath(ovalIn: CGRect(x: $0.x - r, y: $0.y - r, width: r*2, height: r*2)).fill() }
    }

    // MARK: – Size label

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

    // MARK: – Hints

    private func drawHint() {
        let shortcut = Settings.shared.captureShortcutDisplay
        let text = "Drag to select an area   •   \(shortcut) to capture   •   ESC to cancel"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.80)
        ]
        let pad: CGFloat = 8
        let sz = (text as NSString).size(withAttributes: attrs)
        let margin: CGFloat = 20
        let bx = CGRect(x: margin, y: margin, width: sz.width + pad * 2, height: sz.height + pad)
        let bg = NSBezierPath(roundedRect: bx, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.60).setFill()
        bg.fill()
        (text as NSString).draw(at: CGPoint(x: bx.minX + pad, y: bx.minY + pad / 2), withAttributes: attrs)
    }

    private func drawEscHint() {
        let text = "ESC"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.50)
        ]
        let pad: CGFloat = 6
        let sz = (text as NSString).size(withAttributes: attrs)
        let margin: CGFloat = 20
        let bx = CGRect(x: bounds.width - sz.width - pad * 2 - margin, y: margin,
                        width: sz.width + pad * 2, height: sz.height + pad/2)
        let bg = NSBezierPath(roundedRect: bx, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.45).setFill()
        bg.fill()
        (text as NSString).draw(at: CGPoint(x: bx.minX + pad, y: bx.minY + pad/4), withAttributes: attrs)
    }

    // MARK: – Mouse tracking for crosshair

    override func mouseMoved(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
    }
}
