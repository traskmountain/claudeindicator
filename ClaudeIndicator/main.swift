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
                    let indicator = getIndicatorForSession(session)
                    let tabInfo = getTerminalTabInfo(for: session)

                    let title = tabInfo.isEmpty ? "   \(indicator) \(projectName)" : "   \(indicator) \(projectName) — \(tabInfo)"
                    let item = NSMenuItem(
                        title: title,
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

        // Add preferences submenu
        let prefsItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        let prefsMenu = NSMenu()

        let currentWindow = SettingsManager.shared.sessionTimeWindowMinutes
        let timeWindowItem = NSMenuItem(title: "Session Time Window: \(formatTimeWindow(currentWindow))", action: nil, keyEquivalent: "")
        timeWindowItem.isEnabled = false
        prefsMenu.addItem(timeWindowItem)

        for (label, minutes) in SettingsManager.presets {
            let item = NSMenuItem(title: "  \(label)", action: #selector(changeTimeWindow(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            if minutes == currentWindow {
                item.state = .on
            }
            prefsMenu.addItem(item)
        }

        prefsItem.submenu = prefsMenu
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Add Refresh Sessions option
        let refreshItem = NSMenuItem(title: "Refresh Sessions", action: #selector(refreshSessions(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeIndicator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    func getIndicatorForSession(_ session: SessionInfo) -> String {
        guard let type = session.questionType else { return "❓" }
        switch type {
        case "AskUserQuestion":
            return "❓"
        case "ToolPending":
            return "⏸"
        case "UserPrompt":
            return "🔴"
        default:
            return "❓"
        }
    }

    func formatTimeWindow(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            let days = minutes / 1440
            return "\(days) day\(days > 1 ? "s" : "")"
        }
    }

    @objc func changeTimeWindow(_ sender: NSMenuItem) {
        SettingsManager.shared.sessionTimeWindowMinutes = sender.tag
        // Force a refresh
        sessionMonitor.checkAllSessionsNow()
        updateDockMenu()
    }

    @objc func refreshSessions(_ sender: NSMenuItem) {
        print("Manual refresh requested")
        sessionMonitor.checkAllSessionsNow()

        // Show brief notification
        let notification = NSUserNotification()
        notification.title = "Refreshing Sessions"
        notification.informativeText = "Scanning for Claude Code sessions..."
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)

        // Update menu after a short delay to show refreshed data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateDockMenu()
        }
    }

    @objc func openTerminalForSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? SessionInfo else { return }

        let projectName = extractProjectName(from: session.projectPath)
        let projectPath = session.projectPath

        print("Attempting to focus window:")
        print("  Project Name: \(projectName)")
        print("  Project Path: \(projectPath)")

        // Escape quotes in paths for AppleScript
        let escapedName = projectName.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedPath = projectPath.replacingOccurrences(of: "\"", with: "\\\"")

        // Build AppleScript to find and focus the window
        let script = """
        set windowFound to false
        set targetPath to "\(escapedPath)"
        set projectName to "\(escapedName)"

        -- Try Terminal.app
        try
            tell application "Terminal"
                if running then
                    activate
                    repeat with w in windows
                        try
                            set winName to name of w
                            if winName contains projectName or winName contains targetPath then
                                set index of w to 1
                                set windowFound to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end if
            end tell
        end try

        -- Try iTerm2
        if not windowFound then
            try
                tell application "iTerm"
                    if running then
                        activate
                        repeat with w in windows
                            repeat with t in tabs of w
                                repeat with s in sessions of t
                                    try
                                        set sessName to name of s
                                        if sessName contains projectName or sessName contains targetPath then
                                            tell current window
                                                set index to 1
                                            end tell
                                            select w
                                            tell w
                                                select t
                                            end tell
                                            set windowFound to true
                                            exit repeat
                                        end if
                                    end try
                                end repeat
                                if windowFound then exit repeat
                            end repeat
                            if windowFound then exit repeat
                        end repeat
                    end if
                end tell
            end try
        end if

        -- Try WezTerm - just activate for now since window API is limited
        if not windowFound then
            try
                tell application "System Events"
                    if exists process "wezterm-gui" then
                        tell process "wezterm-gui"
                            set frontmost to true
                            set windowFound to true
                        end tell
                    end if
                end tell
            end try
        end if

        return windowFound
        """

        var errorDict: NSDictionary?
        var windowFound = false

        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&errorDict)
            windowFound = result.booleanValue
            print("  Window Found: \(windowFound)")
            if let error = errorDict {
                print("  AppleScript error: \(error)")
            }
        } else {
            print("  Failed to create AppleScript")
        }

        // Show notification
        let notification = NSUserNotification()
        if windowFound {
            notification.title = "Terminal Activated"
            notification.informativeText = "Focused: \(projectName)"
        } else {
            notification.title = "Could Not Find Window"
            notification.informativeText = "Searching for: \(projectName)"
            // Copy path to clipboard as fallback
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(projectPath, forType: .string)
        }
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

    func getTerminalTabInfo(for session: SessionInfo) -> String {
        let projectName = extractProjectName(from: session.projectPath)
        let projectPath = session.projectPath

        let escapedName = projectName.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedPath = projectPath.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        set tabInfo to ""

        -- Try Terminal.app
        try
            tell application "Terminal"
                if running then
                    repeat with w in windows
                        try
                            set winName to name of w
                            if winName contains "\(escapedName)" or winName contains "\(escapedPath)" then
                                -- Extract the middle part (between project name and command)
                                set tabInfo to winName
                                exit repeat
                            end if
                        end try
                    end repeat
                end if
            end tell
        end try

        -- Try iTerm2
        if tabInfo is "" then
            try
                tell application "iTerm"
                    if running then
                        repeat with w in windows
                            repeat with t in tabs of w
                                repeat with s in sessions of t
                                    try
                                        set sessName to name of s
                                        if sessName contains "\(escapedName)" or sessName contains "\(escapedPath)" then
                                            set tabInfo to sessName
                                            exit repeat
                                        end if
                                    end try
                                end repeat
                                if tabInfo is not "" then exit repeat
                            end repeat
                            if tabInfo is not "" then exit repeat
                        end repeat
                    end if
                end tell
            end try
        end if

        return tabInfo
        """

        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&errorDict)
            let fullTitle = result.stringValue ?? ""

            // Extract meaningful part from window title
            // Format: "projectname — activity — command ◂ more — dimensions"
            // We want to extract "activity — command" part
            return extractTabDescription(from: fullTitle, projectName: projectName)
        }

        return ""
    }

    func extractTabDescription(from fullTitle: String, projectName: String) -> String {
        // Remove the project name from the beginning
        var description = fullTitle

        // Find the project name and remove everything before and including it
        if let range = description.range(of: projectName) {
            description = String(description[range.upperBound...])
        }

        // Clean up separators at the start
        description = description.trimmingCharacters(in: CharacterSet(charactersIn: " —"))

        // Split by common separators and take meaningful parts
        let components = description.components(separatedBy: " — ")

        // Take first 2-3 meaningful components
        var meaningful: [String] = []
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            // Skip dimension info (like "122×33")
            if trimmed.contains("×") || trimmed.contains("TMPDIR") {
                break
            }
            // Skip empty or very short components
            if trimmed.count > 1 && !trimmed.starts(with: "◂") {
                meaningful.append(trimmed)
            }
            if meaningful.count >= 2 {
                break
            }
        }

        let result = meaningful.joined(separator: " — ")
        return result.isEmpty ? "" : result
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
