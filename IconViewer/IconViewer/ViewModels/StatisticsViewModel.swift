import Foundation

struct StatisticsViewModel {
    let allIcons: [IconItem]
    let cache: ThumbnailCache
    let sourceDirectories: [URL]
    let lastIndexedAt: Date?
    let lastIndexDuration: TimeInterval?

    var totalActive: Int {
        allIcons.filter { !$0.isQuarantined }.count
    }

    var totalQuarantined: Int {
        allIcons.filter { $0.isQuarantined }.count
    }

    var quarantineBreakdown: [(QuarantineReason, Int)] {
        let quarantined = allIcons.filter { $0.isQuarantined }
        var counts: [QuarantineReason: Int] = [:]
        for item in quarantined {
            if let reason = item.quarantineReason {
                counts[reason, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    var svgCount: Int {
        allIcons.filter { $0.fileExtension == "svg" && !$0.isQuarantined }.count
    }

    var pngCount: Int {
        allIcons.filter { $0.fileExtension == "png" && !$0.isQuarantined }.count
    }

    var directoryBreakdown: [(URL, Int)] {
        sourceDirectories.map { dir in
            let count = allIcons.filter { $0.fileURL.path.hasPrefix(dir.path) && !$0.isQuarantined }.count
            return (dir, count)
        }
    }

    var cacheSize: String {
        let bytes = (try? cache.sizeOnDisk()) ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var lastIndexedDisplay: String {
        guard let date = lastIndexedAt else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var lastIndexDurationDisplay: String {
        guard let duration = lastIndexDuration else { return "—" }
        if duration < 1 { return "< 1s" }
        return String(format: "%.1fs", duration)
    }
}
