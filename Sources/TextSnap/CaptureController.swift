import AppKit
import ScreenCaptureKit

class CaptureController {
    private var overlayWindows: [ScreenCaptureOverlayWindow] = []
    private var isCapturing = false

    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true

        overlayWindows = NSScreen.screens.map { screen in
            let w = ScreenCaptureOverlayWindow(screen: screen)
            w.onSelectionComplete = { [weak self] rect, scr in
                self?.performCapture(selection: rect, screen: scr)
            }
            w.onCancelled = { [weak self] in
                self?.dismissOverlays()
            }
            w.makeKeyAndOrderFront(nil)
            return w
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: – Capture selected region

    private func performCapture(selection: CGRect, screen: NSScreen) {
        dismissOverlays()

        Task {
            do {
                let image = try await captureRect(selection, on: screen)
                let result = await VisionAnalyzer.analyze(image: image)

                await MainActor.run {
                    switch result {
                    case .text(let str):
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(str, forType: .string)
                        ToastController.shared.show(.text, preview: str)

                    case .barcode(let payload, let sym):
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(payload, forType: .string)
                        ToastController.shared.show(.barcode(sym), preview: payload)

                    case .empty:
                        ToastController.shared.show(.noContent, preview: "")
                    }
                }
            } catch {
                await MainActor.run {
                    ToastController.shared.show(.noContent, preview: "")
                }
            }
        }
    }

    // MARK: – SCScreenshotManager capture

    private func captureRect(_ rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.current

        guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw CaptureError.displayNotFound
        }

        // Exclude our own app so the overlay is never in the shot
        let excluded = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])

        // Convert selection (AppKit: origin bottom-left) → display (top-left) in logical pts
        let dh = screen.frame.height
        let displayRect = CGRect(x: rect.minX, y: dh - rect.maxY, width: rect.width, height: rect.height)

        let cfg = SCStreamConfiguration()
        cfg.sourceRect = displayRect
        let scale = screen.backingScaleFactor
        cfg.width  = max(1, Int(rect.width  * scale))
        cfg.height = max(1, Int(rect.height * scale))
        cfg.scalesToFit = false
        cfg.showsCursor = false

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
    }

    // MARK: – Helpers

    private func dismissOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows = []
        isCapturing = false
    }
}

enum CaptureError: Error {
    case displayNotFound
}
