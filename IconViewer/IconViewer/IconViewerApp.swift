import SwiftUI

@main
struct IconViewerApp: App {
    @StateObject private var viewModel = IconCatalogViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(after: .appInfo) {
                OpenWindowButton(id: "statistics", label: "Statistics...")
                    .keyboardShortcut("i", modifiers: [.command])

                OpenWindowButton(id: "quarantine", label: "Quarantine...")
                    .keyboardShortcut("q", modifiers: [.command, .shift])
            }
        }

        Settings {
            PreferencesView(viewModel: viewModel)
        }

        Window("Statistics", id: "statistics") {
            StatisticsView(stats: StatisticsViewModel(
                allIcons: viewModel.allIcons,
                cache: viewModel.cache,
                sourceDirectories: viewModel.sourceDirectories,
                lastIndexedAt: viewModel.lastIndexedAt,
                lastIndexDuration: viewModel.lastIndexDuration
            ))
        }
        .defaultSize(width: 400, height: 450)

        Window("Quarantine", id: "quarantine") {
            QuarantineView(viewModel: viewModel)
        }
        .defaultSize(width: 500, height: 400)
    }
}

/// Helper view that uses @Environment(\.openWindow) to open a window by ID from a menu command.
struct OpenWindowButton: View {
    let id: String
    let label: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(label) {
            openWindow(id: id)
        }
    }
}
