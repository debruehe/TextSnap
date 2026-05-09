import AppKit

class CaptureController {
    private var overlayWindows: [ScreenCaptureOverlayWindow] = []
    private var capturedImages: [CGDirectDisplayID: CGImage] = [:]
    private var isCapturing = false

    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true

        // Snapshot every display before the overlay appears so dropdowns are frozen in the image
        capturedImages = [:]
        overlayWindows = NSScreen.screens.compactMap { screen in
            guard let image = CGDisplayCreateImage(screen.displayID) else { return nil }
            capturedImages[screen.displayID] = image

            let w = ScreenCaptureOverlayWindow(screen: screen, backgroundImage: image)
            w.onSelectionComplete = { [weak self] rect, scr in
                self?.performCapture(selection: rect, screen: scr)
            }
            w.onCancelled = { [weak self] in
                self?.dismissOverlays()
            }
            w.orderFrontRegardless()
            return w
        }
    }

    // MARK: – Crop the pre-captured image to the selection

    private func performCapture(selection: CGRect, screen: NSScreen) {
        guard let image = capturedImages[screen.displayID] else {
            dismissOverlays()
            return
        }
        dismissOverlays()

        Task {
            let scale = screen.backingScaleFactor
            let pixelRect = CGRect(
                x: selection.minX * scale,
                y: (screen.frame.height - selection.maxY) * scale,
                width: selection.width * scale,
                height: selection.height * scale
            )

            guard let cropped = image.cropping(to: pixelRect) else {
                await MainActor.run { ToastController.shared.show(.noContent, preview: "") }
                return
            }

            let result = await VisionAnalyzer.analyze(image: cropped)

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
        }
    }

    // MARK: – Helpers

    private func dismissOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows = []
        capturedImages = [:]
        isCapturing = false
    }
}

enum CaptureError: Error {
    case displayNotFound
}
