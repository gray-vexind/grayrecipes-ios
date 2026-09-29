import Foundation
import Vision
import UIKit

/// On-device text recognition using the Vision framework. Runs entirely on the
/// device (no network) so the user gets an instant preview of the captured text
/// while the higher-accuracy server extraction runs in the background.
enum OnDeviceOCR {
    /// Recognize text lines from an image. Returns lines in reading order.
    static func recognizeText(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Sort roughly top-to-bottom (Vision origin is bottom-left).
                let sorted = observations.sorted { a, b in
                    a.boundingBox.origin.y > b.boundingBox.origin.y
                }
                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

extension UIImage {
    /// Map UIImage orientation to the CGImagePropertyOrientation Vision expects.
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
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
