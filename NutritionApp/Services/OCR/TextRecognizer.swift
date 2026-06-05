import Vision
import UIKit

/// Ein erkanntes Textstück inkl. Position (Vision-Normalkoordinaten, Ursprung unten links).
struct TextToken: Sendable {
    let text: String
    let rect: CGRect
}

/// On-device Texterkennung (Apple Vision). Kostenlos, privat – keine Cloud.
/// Liefert die erkannten Zeilen von oben nach unten.
enum TextRecognizer {

    /// Wie `recognizeLines`, aber mit Bounding-Box je Textstück – für die räumliche
    /// Paarung von Nährwert-Namen und -Werten (zweispaltige Etiketten).
    static func recognizeTokens(from data: Data,
                                orientation: CGImagePropertyOrientation = .up) async -> [TextToken] {
        await withCheckedContinuation { (cont: CheckedContinuation<[TextToken], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, _ in
                    let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                    let tokens = observations.compactMap { o -> TextToken? in
                        guard let s = o.topCandidates(1).first?.string else { return nil }
                        return TextToken(text: s, rect: o.boundingBox)
                    }
                    cont.resume(returning: tokens)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["de-DE", "en-US"]
                let handler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
                do { try handler.perform([request]) } catch { cont.resume(returning: []) }
            }
        }
    }

    static func recognizeLines(from data: Data,
                               orientation: CGImagePropertyOrientation = .up) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, _ in
                    let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                    // Vision-Koordinaten sind von unten nach oben → nach minY absteigend = oben zuerst.
                    let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                    let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                    cont.resume(returning: lines)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["de-DE", "en-US"]

                let handler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: [])
                }
            }
        }
    }

    static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
