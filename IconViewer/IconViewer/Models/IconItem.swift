import Foundation
import AppKit

struct IconItem: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let fileName: String
    let fileExtension: String
    let contentHash: String
    let width: Int
    let height: Int
    let isMonochrome: Bool
    var quarantineReason: QuarantineReason?

    var isQuarantined: Bool { quarantineReason != nil }
    var displayName: String { fileURL.deletingPathExtension().lastPathComponent }
    var dimensions: String { "\(width) x \(height)" }

    init(fileURL: URL, contentHash: String, width: Int, height: Int,
         isMonochrome: Bool = false, quarantineReason: QuarantineReason? = nil) {
        self.id = UUID()
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.fileExtension = fileURL.pathExtension.lowercased()
        self.contentHash = contentHash
        self.width = width
        self.height = height
        self.isMonochrome = isMonochrome
        self.quarantineReason = quarantineReason
    }
}
