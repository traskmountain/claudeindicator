import Foundation

class DirectoryWatcher {
    private let path: String
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.claudeindicator.directorywatcher")

    init(path: String, callback: @escaping () -> Void) {
        self.path = path
        self.callback = callback

        startWatching()
    }

    private func startWatching() {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open directory for watching: \(path)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .revoke],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.callback()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
