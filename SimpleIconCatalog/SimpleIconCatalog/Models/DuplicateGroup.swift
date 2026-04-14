import Foundation

struct DuplicateGroup: Identifiable {
    let id: String  // content hash
    let icons: [IconItem]

    var count: Int { icons.count }
    var totalBytes: Int64 { icons.reduce(0) { $0 + $1.fileSize } }
    /// Bytes that would be reclaimed by deleting all but one copy.
    var wastedBytes: Int64 { icons.dropFirst().reduce(0) { $0 + $1.fileSize } }
}
