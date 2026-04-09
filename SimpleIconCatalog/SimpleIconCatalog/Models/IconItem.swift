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
    let fileSize: Int64
    let modificationDate: Date
    var quarantineReason: QuarantineReason?

    var isQuarantined: Bool { quarantineReason != nil }
    var displayName: String { fileURL.deletingPathExtension().lastPathComponent }
    var dimensions: String { "\(width) x \(height)" }

    init(fileURL: URL, contentHash: String, width: Int, height: Int,
         isMonochrome: Bool = false, fileSize: Int64 = 0,
         modificationDate: Date = Date(), quarantineReason: QuarantineReason? = nil) {
        self.id = UUID()
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.fileExtension = fileURL.pathExtension.lowercased()
        self.contentHash = contentHash
        self.width = width
        self.height = height
        self.isMonochrome = isMonochrome
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.quarantineReason = quarantineReason
    }
}
