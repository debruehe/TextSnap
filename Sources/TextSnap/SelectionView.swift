import AppKit

class SelectionView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var selOrigin: NSPoint?
    private var selSize: NSSize = .zero
    private var isDragging = false
    private var moveMode = false
    private var moveAnchor: NSPoint = .zero

    private var selectionRect: CGRect {
        guard let o = selOrigin else { return .zero }
        return CGRect(origin: o, size: selSize)
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
        let p = convert(event.locationInWindow, from: nil)
        selOrigin = p
        selSize = .zero
        isDragging = true
        moveMode = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let shiftHeld = event.modifierFlags.contains(.shift)

        if shiftHeld && !moveMode && selSize.width > 1 && selSize.height > 1 {
            // Enter move mode — lock current rect, set anchor at cursor
            moveMode = true
            moveAnchor = p
        }

        if moveMode {
            // Move the entire selection by cursor delta
            let dx = p.x - moveAnchor.x
            let dy = p.y - moveAnchor.y
            let newX = max(0, min(selOrigin!.x + dx, bounds.width - selSize.width))
            let newY = max(0, min(selOrigin!.y + dy, bounds.height - selSize.height))
            selOrigin = CGPoint(x: newX, y: newY)
            moveAnchor = p
        } else {
            // Normal resize — expand from origin to cursor
            let sx = min(selOrigin!.x, p.x)
            let sy = min(selOrigin!.y, p.y)
            let sw = abs(p.x - selOrigin!.x)
            let sh = abs(p.y - selOrigin!.y)
            selOrigin = CGPoint(x: sx, y: sy)
            selSize = NSSize(width: sw, height: sh)
            moveMode = false
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        moveMode = false
        needsDisplay = true

        let rect = selectionRect
        guard rect.width > 5, rect.height > 5 else { onCancelled?(); return }
        onSelectionComplete?(rect)
    }

    override func flagsChanged(with event: NSEvent) {
        // If shift is released while dragging, snap back to resize mode
        if isDragging && moveMode && !event.modifierFlags.contains(.shift) {
            moveMode = false
        }
        needsDisplay = true
    }

    // MARK: – Drawing

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSColor.black.withAlphaComponent(0.45)
        let rect = selectionRect

        if isDragging || (selOrigin != nil && rect.width > 1 && rect.height > 1) {
            // Draw dim in four strips around the selection
            dim.setFill()
            [
                CGRect(x: 0, y: rect.maxY, width: bounds.width, height: bounds.maxY - rect.maxY),
                CGRect(x: 0, y: 0,         width: bounds.width, height: rect.minY),
                CGRect(x: 0, y: rect.minY, width: rect.minX,    height: rect.height),
                CGRect(x: rect.maxX, y: rect.minY, width: bounds.maxX - rect.maxX, height: rect.height)
            ].forEach { NSBezierPath(rect: $0).fill() }

            // Selection border — dashed when in move mode
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.75, dy: 0.75))
            border.lineWidth = 1.5
            if moveMode {
                border.setLineDash([6, 3], count: 2, phase: 0)
            }
            NSColor.white.setStroke()
            border.stroke()

            if !moveMode, let cp = currentPoint(for: rect) {
                drawCrosshairs(at: cp, excluding: rect)
            }
            drawHandles(in: rect)
            drawSizeLabel(for: rect)
            if moveMode { drawMoveBadge(in: rect) }
            drawEscHint()
        } else {
            // No selection yet — full dim + hint
            dim.setFill()
            NSBezierPath(rect: bounds).fill()
            drawHint()
            drawEscHint()
            if let cp = lastMousePoint {
                drawCrosshairLines(at: cp)
            }
        }
    }

    private func currentPoint(for rect: CGRect) -> NSPoint? {
        // Approximate cursor position from the rect (bottom-right corner during resize)
        return moveMode ? nil : CGPoint(x: rect.maxX, y: rect.minY)
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
        let text = "⇧ move"
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
        let text = "Drag to select  •  hold ⇧ to move  •  \(shortcut) capture  •  ESC cancel"
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
