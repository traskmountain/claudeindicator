import Foundation

struct ClaudeMessage: Codable {
    let type: String?
    let message: MessageContent?
    let timestamp: String?
    let cwd: String?
    let sessionId: String?

    struct MessageContent: Codable {
        let role: String?
        let content: [Content]?

        struct Content: Codable {
            let type: String?
            let name: String?
            let id: String?
        }
    }
}

struct SessionInfo {
    let filePath: String
    let projectPath: String
    let sessionId: String
    let hasActiveQuestion: Bool
}

class JSONLParser {
    /// Parse a JSONL file and check if it contains an unanswered AskUserQuestion or pending tool
    static func hasActiveQuestion(filePath: String) -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return false
        }

        defer {
            try? fileHandle.close()
        }

        // Read only the last 50KB of the file for better performance
        guard let fileSize = try? fileHandle.seekToEnd() else {
            return false
        }

        let bytesToRead = min(fileSize, 50_000) // Read last 50KB
        if fileSize > bytesToRead {
            try? fileHandle.seek(toOffset: fileSize - bytesToRead)
        } else {
            try? fileHandle.seek(toOffset: 0)
        }

        guard let data = try? fileHandle.readToEnd(),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }

        // Split by newlines and get only complete lines (skip first line as it might be partial)
        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if fileSize > bytesToRead && !lines.isEmpty {
            lines.removeFirst() // Remove potentially partial first line
        }

        // Track if we've seen an AskUserQuestion that hasn't been answered
        var hasUnAnsweredQuestion = false
        var lastMessageWasToolUse = false

        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let message = try? JSONDecoder().decode(ClaudeMessage.self, from: jsonData) else {
                continue
            }

            // Check if this is an assistant message with AskUserQuestion tool
            if message.type == "assistant",
               let content = message.message?.content {
                // Reset tool use flag
                lastMessageWasToolUse = false

                for item in content {
                    if item.name == "AskUserQuestion" {
                        hasUnAnsweredQuestion = true
                    }
                    // Check if this assistant message has ANY tool use
                    if item.type == "tool_use" {
                        lastMessageWasToolUse = true
                    }
                }
            }

            // Check if this is a user message (which would answer the question)
            if message.type == "user" {
                if hasUnAnsweredQuestion {
                    // User has responded, question is no longer active
                    hasUnAnsweredQuestion = false
                }
                // User message or tool_result means the tool completed
                lastMessageWasToolUse = false
            }
        }

        // Return true if there's an unanswered question OR a pending tool execution
        return hasUnAnsweredQuestion || lastMessageWasToolUse
    }

    /// Get all JSONL session files in the Claude projects directory
    static func getAllSessionFiles() -> [String] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let projectsPath = homeDir.appendingPathComponent(".claude/projects")

        guard let enumerator = FileManager.default.enumerator(
            at: projectsPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sessionFiles: [String] = []

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "jsonl" {
                sessionFiles.append(fileURL.path)
            }
        }

        return sessionFiles
    }

    /// Get detailed session information including project path and question status
    static func getSessionInfo(filePath: String) -> SessionInfo? {
        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return nil
        }

        defer {
            try? fileHandle.close()
        }

        // Read only the last 50KB of the file for better performance
        guard let fileSize = try? fileHandle.seekToEnd() else {
            return nil
        }

        let bytesToRead = min(fileSize, 50_000) // Read last 50KB
        if fileSize > bytesToRead {
            try? fileHandle.seek(toOffset: fileSize - bytesToRead)
        } else {
            try? fileHandle.seek(toOffset: 0)
        }

        guard let data = try? fileHandle.readToEnd(),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Split by newlines and get only complete lines (skip first line as it might be partial)
        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if fileSize > bytesToRead && !lines.isEmpty {
            lines.removeFirst() // Remove potentially partial first line
        }

        var hasUnAnsweredQuestion = false
        var lastMessageWasToolUse = false
        var projectPath = ""
        var sessionId = ""

        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let message = try? JSONDecoder().decode(ClaudeMessage.self, from: jsonData) else {
                continue
            }

            // Extract metadata from first message
            if projectPath.isEmpty, let cwd = message.cwd {
                projectPath = cwd
            }
            if sessionId.isEmpty, let sid = message.sessionId {
                sessionId = sid
            }

            // Check for AskUserQuestion and tool use
            if message.type == "assistant",
               let content = message.message?.content {
                lastMessageWasToolUse = false

                for item in content {
                    if item.name == "AskUserQuestion" {
                        hasUnAnsweredQuestion = true
                    }
                    if item.type == "tool_use" {
                        lastMessageWasToolUse = true
                    }
                }
            }

            // Check if answered
            if message.type == "user" {
                if hasUnAnsweredQuestion {
                    hasUnAnsweredQuestion = false
                }
                lastMessageWasToolUse = false
            }
        }

        let hasActiveQuestion = hasUnAnsweredQuestion || lastMessageWasToolUse

        // Extract project name from path
        if projectPath.isEmpty {
            // Try to get from file path
            let url = URL(fileURLWithPath: filePath)
            let projectFolder = url.deletingLastPathComponent().lastPathComponent
            projectPath = projectFolder.replacingOccurrences(of: "-Users-red-", with: "~/")
        }

        return SessionInfo(
            filePath: filePath,
            projectPath: projectPath,
            sessionId: sessionId,
            hasActiveQuestion: hasActiveQuestion
        )
    }

    /// Get all sessions with their information
    static func getAllSessionInfo() -> [SessionInfo] {
        let files = getAllSessionFiles()
        return files.compactMap { getSessionInfo(filePath: $0) }
    }
}
