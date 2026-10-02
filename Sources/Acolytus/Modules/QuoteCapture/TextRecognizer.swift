import AcolytusCore
import CoreGraphics
import Vision

/// OCR local con Vision: nada sale del Mac.
enum TextRecognizer {
    static func lines(in image: CGImage) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["es-ES", "en-US"]

        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            // Vision usa origen abajo a la izquierda; OCRLine, arriba a la izquierda.
            let box = observation.boundingBox
            return OCRLine(text: candidate.string,
                           top: 1 - box.maxY,
                           left: box.minX,
                           height: box.height)
        }
    }
}
