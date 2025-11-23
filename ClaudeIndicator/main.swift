import Cocoa
import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let sessionMonitor = ClaudeSessionMonitor()
    var dockMenu: NSMenu?
    var currentSessions: [SessionInfo] = []
    var lastQuestionState = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set up the app to show in dock
        NSApp.setActivationPolicy(.regular)

        // Create dock menu
        setupDockMenu()

        // Initialize monitoring
        sessionMonitor.delegate = self
        sessionMonitor.startMonitoring()

        // Set initial green icon
        updateDockIcon(isAsking: false)

        print("ClaudeIndicator started - monitoring Claude Code sessions")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        sessionMonitor.stopMonitoring()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return dockMenu
    }

    func setupDockMenu() {
        dockMenu = NSMenu()
        updateDockMenu()
    }

    func updateDockMenu() {
        guard let menu = dockMenu else { return }
        menu.removeAllItems()

        if currentSessions.isEmpty {
            let item = NSMenuItem(title: "No active Claude Code sessions", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Group sessions
            let sessionsWithQuestions = currentSessions.filter { $0.hasActiveQuestion }
            let otherSessions = currentSessions.filter { !$0.hasActiveQuestion }

            if !sessionsWithQuestions.isEmpty {
                let header = NSMenuItem(title: "Sessions with Questions:", action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)

                for session in sessionsWithQuestions {
                    let projectName = extractProjectName(from: session.projectPath)
                    let item = NSMenuItem(
                        title: "   \(projectName)",
                        action: #selector(openTerminalForSession(_:)),
                        keyEquivalent: ""
                    )
                    item.representedObject = session
                    item.target = self
                    menu.addItem(item)
                }

                menu.addItem(NSMenuItem.separator())
            }

            if !otherSessions.isEmpty {
                let header = NSMenuItem(title: "Other Active Sessions:", action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)

                for session in otherSessions.prefix(5) {
                    let projectName = extractProjectName(from: session.projectPath)
                    let item = NSMenuItem(
                        title: "   \(projectName)",
                        action: #selector(openTerminalForSession(_:)),
                        keyEquivalent: ""
                    )
                    item.representedObject = session
                    item.target = self
                    menu.addItem(item)
                }
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeIndicator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func openTerminalForSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? SessionInfo else { return }

        // Try to find and activate the terminal window
        // This is a best-effort approach - we'll use AppleScript to find terminals at this path
        let script = """
        tell application "System Events"
            set terminalApps to {"Terminal", "iTerm", "iTerm2", "WezTerm", "Alacritty", "Kitty"}
            repeat with termApp in terminalApps
                if exists process termApp then
                    tell process termApp to set frontmost to true
                    return
                end if
            end repeat
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }

        // Also copy the project path to clipboard for convenience
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.projectPath, forType: .string)

        // Show a notification
        let notification = NSUserNotification()
        notification.title = "Claude Session"
        notification.informativeText = "Project path copied: \(extractProjectName(from: session.projectPath))"
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }

    func extractProjectName(from path: String) -> String {
        if path.isEmpty {
            return "Unknown Project"
        }
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    func updateDockIcon(isAsking: Bool) {
        let icon = DockIconGenerator.createIcon(isAsking: isAsking)
        NSApp.applicationIconImage = icon
    }
}

extension AppDelegate: SessionMonitorDelegate {
    func sessionStateDidChange(isAskingQuestion: Bool, sessions: [SessionInfo]) {
        DispatchQueue.main.async {
            self.currentSessions = sessions
            self.updateDockIcon(isAsking: isAskingQuestion)
            self.updateDockMenu()

            // Only play sound if state changed from false to true
            if isAskingQuestion && !self.lastQuestionState {
                SoundManager.playAlert()
            }
            self.lastQuestionState = isAskingQuestion
        }
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
