import Foundation

enum QuarantineReason: String, Codable, CaseIterable {
    case tooLarge
    case tooSmall
    case badAspectRatio
    case corrupted
    case manualExclude

    var displayName: String {
        switch self {
        case .tooLarge: return "Too large (>1024px)"
        case .tooSmall: return "Too small (<16px)"
        case .badAspectRatio: return "Bad aspect ratio (>2:1)"
        case .corrupted: return "Corrupted or unreadable"
        case .manualExclude: return "Manually excluded"
        }
    }
}
