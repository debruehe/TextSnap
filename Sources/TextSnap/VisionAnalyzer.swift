import Vision
import CoreImage

enum AnalysisResult {
    case text(String)
    case barcode(payload: String, symbology: String)
    case empty
}

enum VisionAnalyzer {
    static func analyze(image: CGImage) async -> AnalysisResult {
        await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            let barcodeReq = VNDetectBarcodesRequest()
            barcodeReq.symbologies = [
                .qr, .aztec, .dataMatrix,
                .code128, .code39, .ean8, .ean13, .upce,
                .pdf417, .itf14, .gs1DataBar, .gs1DataBarExpanded
            ]

            let textReq = VNRecognizeTextRequest()
            textReq.recognitionLevel = .accurate
            textReq.usesLanguageCorrection = true
            textReq.automaticallyDetectsLanguage = true

            do {
                try handler.perform([barcodeReq, textReq])

                // Prefer barcode if detected
                if let results = barcodeReq.results, !results.isEmpty,
                   let first = results.first,
                   let payload = first.payloadStringValue {
                    let sym = first.symbology.rawValue
                        .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
                    continuation.resume(returning: .barcode(payload: payload, symbology: sym))
                    return
                }

                // OCR fallback
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
