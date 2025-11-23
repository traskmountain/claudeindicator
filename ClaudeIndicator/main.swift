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

        // Copy the project path to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.projectPath, forType: .string)

        // Try to activate Terminal and bring it to front
        let script = """
        tell application "System Events"
            -- Check for various terminal apps
            set terminalFound to false

            -- Try Terminal
            if exists process "Terminal" then
                tell process "Terminal"
                    set frontmost to true
                end tell
                set terminalFound to true
            end if

            -- Try iTerm2
            if not terminalFound and exists process "iTerm2" then
                tell application "iTerm2"
                    activate
                end tell
                set terminalFound to true
            end if

            -- Try iTerm
            if not terminalFound and exists process "iTerm" then
                tell application "iTerm"
                    activate
                end tell
                set terminalFound to true
            end if

            -- Try WezTerm
            if not terminalFound and exists process "wezterm-gui" then
                tell process "wezterm-gui"
                    set frontmost to true
                end tell
                set terminalFound to true
            end if
        end tell
        """

        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&errorDict)
            if let error = errorDict {
                print("AppleScript error: \(error)")
            }
        }

        // Show a notification
        let notification = NSUserNotification()
        notification.title = "Terminal Activated"
        notification.informativeText = "Path copied: \(extractProjectName(from: session.projectPath))"
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
