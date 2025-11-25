# ClaudeIndicator - Development Guide

## Overview
ClaudeIndicator is a macOS dock application that monitors all Claude Code sessions and provides visual feedback when Claude is waiting for user input. The dock icon changes from green (idle) to red (waiting) and displays session information via a right-click menu.

## Architecture

### Core Components

**main.swift** - Application entry point and UI management
- Sets up dock menu and icon
- Handles session state changes
- Manages menu updates with session information
- Provides click handlers for terminal activation

**ClaudeSessionMonitor.swift** - Session orchestration
- Monitors all Claude Code sessions via file system watching
- Polls every 0.5 seconds for changes
- Filters sessions by configurable time window
- Aggregates state across all sessions
- Delegates state changes to the app

**JSONLParser.swift** - Log file parsing
- Parses `.jsonl` session files from `~/.claude/projects/`
- Detects three types of waiting states:
  1. `AskUserQuestion` tool usage (formal blocking questions)
  2. Pending tool execution (tool_use without tool_result)
  3. Unanswered user prompt (user message without assistant response)
- Extracts session metadata (project path, session ID, last modified time, question type)
- Tracks question type for visual indicators

**SettingsManager.swift** - Preferences management
- UserDefaults-based storage for persistent settings
- Manages session time window (default: 60 minutes)
- Provides presets: 5 min, 15 min, 30 min, 1 hour, 4 hours, 1 day

**DirectoryWatcher.swift** - File system monitoring
- Uses DispatchSource for low-level file system events
- Watches `~/.claude/projects/` directory
- Triggers session checks on file changes

**DockIconGenerator.swift** - Dynamic icon creation
- Generates green/red circular icons with "C" symbol
- Creates icons programmatically using NSBezierPath
- Returns NSImage for dock display

**SoundManager.swift** - Audio alerts
- Plays system alert sound when state changes to red
- Uses AudioServicesPlayAlertSound for simplicity

### Detection Logic

The app considers a session "waiting" when:

1. **AskUserQuestion detected:**
   - Last assistant message contains `tool_use` with `name: "AskUserQuestion"`
   - No subsequent user message found

2. **Pending tool execution:**
   - Last message is assistant with any `tool_use`
   - No subsequent user message or tool_result
   - This catches permission prompts and blocked operations

3. **Unanswered user prompt:**
   - User sent a new message/prompt
   - No subsequent assistant response yet
   - Distinguishes between regular prompts and tool_result messages
   - Icon turns red when Claude is actively processing

### JSONL Structure

Claude Code logs sessions in JSONL format at:
```
~/.claude/projects/<project-name>/<session-id>.jsonl
```

Each line is a JSON object representing a message:
```json
{
  "type": "assistant" | "user",
  "cwd": "/path/to/project",
  "sessionId": "uuid",
  "message": {
    "content": [
      {
        "type": "tool_use" | "text",
        "name": "AskUserQuestion" | "Bash" | etc,
        ...
      }
    ]
  }
}
```

### State Flow

```
File System Event or Timer (0.5s)
  → DirectoryWatcher callback or checkAllSessions()
  → JSONLParser.getAllSessionInfo()
  → For each session file:
      → Parse last 50KB of JSONL
      → Check for pending questions/tools/prompts
      → Extract metadata (path, sessionId, lastModified, questionType)
  → Filter sessions by time window (SettingsManager)
  → Aggregate: ANY recent session waiting = RED
  → Notify AppDelegate
  → Update dock icon + menu (with emoji indicators)
  → Play sound if state changed to RED
```

## Building and Testing

### Build
```bash
./build.sh
```

### Run
```bash
open build/ClaudeIndicator.app
```

### Install as Login Item
```bash
./install-login-item.sh
launchctl load ~/Library/LaunchAgents/com.claudecode.indicator.plist
```

### Testing

**Test detection patterns:**
1. **AskUserQuestion (❓)**: Have Claude use AskUserQuestion tool → icon red, session shows ❓
2. **Tool pending (⏸)**: Trigger bash command requiring permission → icon red, session shows ⏸
3. **User prompt (🔴)**: Send message to Claude → icon red immediately, session shows 🔴

**Test time window filtering:**
1. Set time window to 5 minutes (Preferences menu)
2. Archive old sessions: `find ~/.claude/projects -name "*.jsonl" -mtime +1 -exec mv {} ~/.claude/projects-archive/ \;`
3. Verify only recent sessions appear in menu
4. Verify old sessions don't trigger red icon

**Test menu features:**
1. Right-click icon → verify sessions grouped correctly
2. Click session → verify terminal window focuses
3. Click "Refresh Sessions" → verify menu updates
4. Change time window → verify menu updates with filtered sessions

**Test preferences:**
1. Change time window to different presets
2. Restart app → verify setting persisted
3. Sessions outside window should not appear

**Manual detection logic test:**
You can test the detection logic manually using this Swift script:
```bash
cat > /tmp/test_detection.swift << 'EOF'
import Foundation

struct ClaudeMessage: Codable {
    let type: String?
    let message: MessageContent?

    struct MessageContent: Codable {
        let role: String?
        let content: [Content]?

        struct Content: Codable {
            let type: String?
            let name: String?
        }
    }
}

let homeDir = FileManager.default.homeDirectoryForCurrentUser
let filePath = homeDir.appendingPathComponent(".claude/projects/-Users-red-claude-prompt-ClaudeIndicator/b290f2b2-2c24-4d2e-8623-2806e5734c82.jsonl").path

guard let data = try? String(contentsOfFile: filePath, encoding: .utf8) else {
    print("Failed to read file")
    exit(1)
}

let lines = data.components(separatedBy: .newlines).filter { !$0.isEmpty }
print("Total lines: \(lines.count)")

var lastMessageWasToolUse = false
var lastUserPromptAnswered = true
var lastType = ""

for (index, line) in lines.enumerated() {
    guard let jsonData = line.data(using: .utf8),
          let message = try? JSONDecoder().decode(ClaudeMessage.self, from: jsonData) else {
        continue
    }

    if message.type == "assistant", let content = message.message?.content {
        lastUserPromptAnswered = true
        lastMessageWasToolUse = false
        for item in content {
            if item.type == "tool_use" {
                lastMessageWasToolUse = true
                print("Line \(index + 1): Found tool_use, name=\(item.name ?? "none")")
            }
        }
    }

    if message.type == "user" {
        let isToolResult = message.message?.content?.contains { $0.type == "tool_result" } ?? false
        if isToolResult {
            lastMessageWasToolUse = false
        } else {
            lastUserPromptAnswered = false
            print("Line \(index + 1): Found user prompt (unanswered)")
        }
    }

    lastType = message.type ?? "unknown"
}

print("Last message type: \(lastType)")
print("lastMessageWasToolUse: \(lastMessageWasToolUse)")
print("lastUserPromptAnswered: \(lastUserPromptAnswered)")
print("Should show RED: \(lastMessageWasToolUse || !lastUserPromptAnswered)")
EOF

swift /tmp/test_detection.swift
```

## Key Design Decisions

1. **Polling + FSEvents:** Combined approach for reliability
   - FSEvents catches most changes immediately
   - 0.5-second polling catches missed events (faster than original 2s)
   - Ensures no missed state changes

2. **Time-based filtering (NEW):** Prevents false positives from stale sessions
   - Configurable time window (default: 1 hour)
   - Only monitors sessions modified within window
   - Persisted in UserDefaults across app restarts
   - Key improvement addressing "always red" issue

3. **Tool execution detection:** Catches permission prompts
   - Permission prompts don't use AskUserQuestion
   - They appear as pending tool executions
   - Last message is tool_use without result

4. **Question type tracking (NEW):** Visual feedback in menu
   - 🔴 User prompt = actively processing
   - ⏸ Tool pending = waiting for permission
   - ❓ AskUserQuestion = explicit question
   - Helps users identify why session is waiting

5. **Sound only on transition:** Prevents alert spam
   - Only play sound when green → red
   - Silent when staying red or red → green
   - Better user experience

6. **Terminal window focusing (NEW):** Direct navigation to sessions
   - AppleScript searches Terminal.app/iTerm2 windows
   - Matches by project name or full path
   - Brings specific window to front
   - Fallback: copies path to clipboard

## Future Enhancement Ideas

- [ ] Configurable colors/sounds
- [ ] Notification center integration (currently uses deprecated NSUserNotification)
- [ ] Badge count showing number of waiting sessions
- [ ] Status bar mode (menu bar instead of dock)
- [ ] Per-project time window overrides
- [ ] Support for more terminal apps (Kitty, Alacritty)

## Troubleshooting

**Icon stays green when it should be red:**
- Check app is running: `ps aux | grep ClaudeIndicator`
- Verify session files exist: `ls ~/.claude/projects/*//*.jsonl`
- Check file permissions on `~/.claude/projects/`

**Icon always red:**
- Check for stuck sessions with old pending tools
- Look for sessions without user responses
- May need to close stale Claude Code sessions

**Menu doesn't update:**
- Menu updates every 2 seconds
- Try right-clicking again
- Check Console.app for errors

## Code Style Notes

- Swift native, no external dependencies
- Minimal use of third-party frameworks
- Declarative where possible
- Error handling via guard/optional chaining
- Background queue for file I/O
- Main queue for UI updates
