import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.simpleiconcatalog.app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let indexing = Logger(subsystem: subsystem, category: "indexing")
    static let watcher = Logger(subsystem: subsystem, category: "watcher")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let thumbnail = Logger(subsystem: subsystem, category: "thumbnail")
    static let migration = Logger(subsystem: subsystem, category: "migration")
}
