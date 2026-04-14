import Foundation

/// Watches directories for file system changes using GCD's DispatchSource.
/// Calls the onChange callback when any change is detected in watched directories.
class DirectoryWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func watch(directories: [URL]) {
        stop()

        for directory in directories {
            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else {
                AppLog.watcher.error("Failed to open \(directory.path, privacy: .public) for watching")
                continue
            }
            fileDescriptors.append(fd)
            AppLog.watcher.notice("Watching \(directory.path, privacy: .public)")

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .main
            )

            let dirPath = directory.path
            source.setEventHandler { [weak self] in
                AppLog.watcher.debug("Change detected in \(dirPath, privacy: .public)")
                self?.onChange()
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    deinit {
        stop()
    }
}
