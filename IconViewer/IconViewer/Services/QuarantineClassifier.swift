import Foundation

struct QuarantineClassifier {
    let maxDimension: Int = 1024
    let minDimension: Int = 16
    let maxAspectRatio: Double = 2.0

    func classify(width: Int, height: Int) -> QuarantineReason? {
        if width > maxDimension || height > maxDimension {
            return .tooLarge
        }
        if width < minDimension || height < minDimension {
            return .tooSmall
        }
        let aspect = Double(max(width, height)) / Double(max(min(width, height), 1))
        if aspect > maxAspectRatio {
            return .badAspectRatio
        }
        return nil
    }
}
