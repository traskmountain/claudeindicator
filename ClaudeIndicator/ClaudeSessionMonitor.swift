import Foundation

protocol SessionMonitorDelegate: AnyObject {
    func sessionStateDidChange(isAskingQuestion: Bool, sessions: [SessionInfo])
}

class ClaudeSessionMonitor {
    weak var delegate: SessionMonitorDelegate?

    private var fileSystemWatcher: DirectoryWatcher?
    private var currentState: Bool = false
    private var currentSessions: [SessionInfo] = []
    private let checkQueue = DispatchQueue(label: "com.claudeindicator.checkqueue")
    private var checkTimer: Timer?

    func startMonitoring() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let projectsPath = homeDir.appendingPathComponent(".claude/projects").path

        // Initial check
        checkAllSessions()

        // Set up directory watcher
        fileSystemWatcher = DirectoryWatcher(path: projectsPath) { [weak self] in
            self?.checkAllSessions()
        }

        // Also poll periodically (every 2 seconds) to catch any missed changes
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAllSessions()
        }
    }

    func stopMonitoring() {
        fileSystemWatcher?.stop()
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func checkAllSessions() {
        checkQueue.async { [weak self] in
            guard let self = self else { return }

            let sessions = JSONLParser.getAllSessionInfo()
            let hasActiveQuestion = sessions.contains { $0.hasActiveQuestion }

            // Always notify with updated session list
            self.currentState = hasActiveQuestion
            self.currentSessions = sessions

            DispatchQueue.main.async {
                self.delegate?.sessionStateDidChange(isAskingQuestion: hasActiveQuestion, sessions: sessions)
            }
        }
    }

    func getCurrentSessions() -> [SessionInfo] {
        return currentSessions
    }
}
