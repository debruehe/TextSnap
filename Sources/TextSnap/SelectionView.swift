import AppKit

class SelectionView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isDragging = false
    private var moveMode = false
    private var spaceHeld = false
    private var lockedRect: CGRect = .zero
    private var moveAnchor: NSPoint = .zero
    private var justExitedMoveMode = false

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
        moveMode = false
        justExitedMoveMode = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)

        if spaceHeld && !moveMode && selectionRect.width > 1 && selectionRect.height > 1 {
            // Enter move mode
            moveMode = true
            lockedRect = selectionRect
            moveAnchor = p
        }

        if moveMode {
            let dx = p.x - moveAnchor.x
            let dy = p.y - moveAnchor.y
            let newX = max(0, min(lockedRect.origin.x + dx, bounds.width - lockedRect.width))
            let newY = max(0, min(lockedRect.origin.y + dy, bounds.height - lockedRect.height))
            lockedRect.origin = CGPoint(x: newX, y: newY)
            moveAnchor = p
            startPoint = CGPoint(x: lockedRect.minX, y: lockedRect.minY)
            currentPoint = CGPoint(x: lockedRect.maxX, y: lockedRect.maxY)
        } else {
            if justExitedMoveMode {
                justExitedMoveMode = false
                // Re-anchor: start fresh resize from cursor against opposite corner
                let r = selectionRect
                let oppX = (p.x - r.midX) >= 0 ? r.minX : r.maxX
                let oppY = (p.y - r.midY) >= 0 ? r.minY : r.maxY
                startPoint = CGPoint(x: oppX, y: oppY)
            }
            currentPoint = p
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        isDragging = false
        moveMode = false
        needsDisplay = true

        let rect = selectionRect
        guard rect.width > 5, rect.height > 5 else { onCancelled?(); return }
        onSelectionComplete?(rect)
    }

    // MARK: – Space bar tracking (key events, since flagsChanged doesn't fire for space)

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // space
            spaceHeld = true
            return
        }
        if event.keyCode == 53 { // ESC
            onCancelled?()
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceHeld = false
            if moveMode {
                moveMode = false
                justExitedMoveMode = true
            }
            return
        }
        super.keyUp(with: event)
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

            // Selection border — dashed in move mode
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.75, dy: 0.75))
            border.lineWidth = 1.5
            if moveMode { border.setLineDash([6, 3], count: 2, phase: 0) }
            NSColor.white.setStroke()
            border.stroke()

            if !moveMode, let cp = currentPoint {
                drawCrosshairs(at: cp, excluding: rect)
            }
            drawHandles(in: rect)
            drawSizeLabel(for: rect)
            if moveMode { drawMoveBadge(in: rect) }
            drawEscHint()
        } else {
            dim.setFill()
            NSBezierPath(rect: bounds).fill()
            drawHint()
            drawEscHint()
            if let cp = lastMousePoint {
                drawCrosshairLines(at: cp)
            }
        }
    }

    // MARK: – Crosshair guide lines

    private func drawCrosshairLines(at point: NSPoint) {
        let dashes: [CGFloat] = [4, 4]
        let path = NSBezierPath()
        path.lineWidth = 0.5
        path.move(to: CGPoint(x: point.x, y: 0))
        path.line(to: CGPoint(x: point.x, y: bounds.height))
        path.move(to: CGPoint(x: 0, y: point.y))
        path.line(to: CGPoint(x: bounds.width, y: point.y))
        path.setLineDash(dashes, count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.35).setStroke()
        path.stroke()
    }

    private func drawCrosshairs(at point: NSPoint, excluding rect: CGRect) {
        let path = NSBezierPath()
        path.lineWidth = 0.5
        if point.y > rect.maxY {
            path.move(to: CGPoint(x: point.x, y: rect.maxY))
            path.line(to: CGPoint(x: point.x, y: min(point.y, bounds.height)))
        }
        if point.y < rect.minY {
            path.move(to: CGPoint(x: point.x, y: max(point.y, 0)))
            path.line(to: CGPoint(x: point.x, y: rect.minY))
        }
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

    // MARK: – Move badge

    private func drawMoveBadge(in rect: CGRect) {
        let text = "space · move"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.70)
        ]
        let pad: CGFloat = 5
        let sz = (text as NSString).size(withAttributes: attrs)
        let bx = CGRect(x: rect.maxX - sz.width - pad*2, y: rect.maxY + 4,
                        width: sz.width + pad*2, height: sz.height + pad/2)
        let bg = NSBezierPath(roundedRect: bx, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.55).setFill()
        bg.fill()
        (text as NSString).draw(at: CGPoint(x: bx.minX + pad, y: bx.minY + pad/4), withAttributes: attrs)
    }

    // MARK: – Hints

    private func drawHint() {
        let shortcut = Settings.shared.captureShortcutDisplay
        let text = "Drag to select  •  hold space to move  •  \(shortcut) capture  •  ESC cancel"
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

    // MARK: – Mouse tracking

    private var lastMousePoint: NSPoint?

    override func mouseMoved(with event: NSEvent) {
        lastMousePoint = convert(event.locationInWindow, from: nil)
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
