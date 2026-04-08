import Foundation

struct DirectoryScanner {
    private let supportedExtensions: Set<String> = ["svg", "png"]

    func scan(directories: [URL]) async throws -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default

        for directory in directories {
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                results.append(fileURL)
            }
        }

        return results
    }
}
