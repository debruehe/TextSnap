import Vision
import CoreImage

enum AnalysisResult {
    case text(String)
    case barcode(payload: String, symbology: String)
    case empty
}

enum VisionAnalyzer {
    /// Analyzes an image for barcodes first, then falls back to OCR.
    /// Barcode detection is fast and cheap; OCR only runs if no barcode is found.
    static func analyze(image: CGImage) async -> AnalysisResult {
        await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            // Step 1: Try barcode detection first (fast)
            let barcodeReq = VNDetectBarcodesRequest()
            barcodeReq.symbologies = [
                .qr, .aztec, .dataMatrix,
                .code128, .code39, .ean8, .ean13, .upce,
                .pdf417, .itf14, .gs1DataBar, .gs1DataBarExpanded
            ]

            do {
                try handler.perform([barcodeReq])

                if let results = barcodeReq.results, !results.isEmpty,
                   let first = results.first,
                   let payload = first.payloadStringValue {
                    let sym = first.symbology.rawValue
                        .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
                    continuation.resume(returning: .barcode(payload: payload, symbology: sym))
                    return
                }
            } catch {
                // Barcode detection failed, continue to OCR
            }

            // Step 2: OCR fallback (slower, only runs if no barcode found)
            let textReq = VNRecognizeTextRequest()
            textReq.recognitionLevel = .accurate
            textReq.usesLanguageCorrection = true
            textReq.automaticallyDetectsLanguage = true

            do {
                try handler.perform([textReq])

                if let results = textReq.results, !results.isEmpty {
                    let text = results
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        continuation.resume(returning: .text(text))
                        return
                    }
                }

                continuation.resume(returning: .empty)
            } catch {
                continuation.resume(returning: .empty)
            }
        }
    }
}
