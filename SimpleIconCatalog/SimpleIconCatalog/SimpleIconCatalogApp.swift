import SwiftUI

@main
struct SimpleIconCatalogApp: App {
    @StateObject private var viewModel: IconCatalogViewModel
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    init() {
        AppLog.app.notice("App launching — version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?", privacy: .public)")
        LegacyMigration.migrateIfNeeded()
        _viewModel = StateObject(wrappedValue: IconCatalogViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    appearanceMode.apply()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                OpenWindowButton(id: "about", label: "About Simple Icon Catalog")
            }
            CommandGroup(after: .appInfo) {
                OpenWindowButton(id: "statistics", label: "Statistics...")
                    .keyboardShortcut("i", modifiers: [.command])

                OpenWindowButton(id: "quarantine", label: "Quarantine...")
                    .keyboardShortcut("q", modifiers: [.command, .shift])
            }
            CommandGroup(after: .textEditing) {
                Button("Find Icons") {
                    viewModel.focusSearch = true
                }
                .keyboardShortcut("f", modifiers: [.command])
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
                lastIndexDuration: viewModel.lastIndexDuration,
                favoriteCount: viewModel.allIcons.filter { !$0.isQuarantined && viewModel.isFavorite($0) }.count,
                collectionCount: viewModel.collections.count,
                indexStore: viewModel.indexStore
            ))
        }
        .defaultSize(width: 400, height: 450)

        Window("Quarantine", id: "quarantine") {
            QuarantineView(viewModel: viewModel)
        }
        .defaultSize(width: 500, height: 400)

        Window("About Simple Icon Catalog", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
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
