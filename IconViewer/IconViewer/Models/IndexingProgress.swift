import Foundation

struct IndexingProgress {
    var totalFiles: Int = 0
    var processedFiles: Int = 0
    var isIndexing: Bool = false

    var fraction: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    var displayText: String {
        "Indexing... \(processedFiles)/\(totalFiles) files"
    }
}
