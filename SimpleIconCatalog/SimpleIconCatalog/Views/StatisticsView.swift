import SwiftUI

struct StatisticsView: View {
    let stats: StatisticsViewModel

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Active icons", value: "\(stats.totalActive)")
                LabeledContent("Quarantined", value: "\(stats.totalQuarantined)")
            }

            Section("Formats") {
                LabeledContent("SVG", value: "\(stats.svgCount)")
                LabeledContent("PNG", value: "\(stats.pngCount)")
            }

            Section("Directories") {
                ForEach(stats.directoryBreakdown, id: \.0) { dir, count in
                    LabeledContent(dir.lastPathComponent, value: "\(count) icons")
                }
            }

            if !stats.quarantineBreakdown.isEmpty {
                Section("Quarantine Breakdown") {
                    ForEach(stats.quarantineBreakdown, id: \.0) { reason, count in
                        LabeledContent(reason.displayName, value: "\(count)")
                    }
                }
            }

            Section("Library") {
                LabeledContent("Favorites", value: "\(stats.favoriteCount)")
                LabeledContent("Collections", value: "\(stats.collectionCount)")
            }

            Section("Storage") {
                LabeledContent("Thumbnail cache", value: stats.cacheSize)
                LabeledContent("Database", value: stats.databaseSize)
            }

            Section("Last Indexation") {
                LabeledContent("Date", value: stats.lastIndexedDisplay)
                LabeledContent("Duration", value: stats.lastIndexDurationDisplay)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 450)
    }
}
