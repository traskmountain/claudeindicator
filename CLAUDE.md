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
- Polls every 2 seconds for changes
- Aggregates state across all sessions
- Delegates state changes to the app

**JSONLParser.swift** - Log file parsing
- Parses `.jsonl` session files from `~/.claude/projects/`
- Detects two types of waiting states:
  1. `AskUserQuestion` tool usage (formal blocking questions)
  2. Pending tool execution (tool_use without tool_result)
- Extracts session metadata (project path, session ID)

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
File System Event
  → DirectoryWatcher callback
  → ClaudeSessionMonitor.checkAllSessions()
  → JSONLParser.getAllSessionInfo()
  → For each session file:
      → Parse JSONL
      → Check for pending questions/tools
      → Extract metadata
  → Aggregate: ANY session waiting = RED
  → Notify AppDelegate
  → Update dock icon + menu
  → Play sound if state changed
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

**Test AskUserQuestion detection:**
- Have Claude ask a question using the AskUserQuestion tool
- Icon should turn red with sound alert
- Right-click shows session in "Sessions with Questions"
- Answer the question → icon turns green

**Test permission prompt detection:**
- Trigger a bash command that requires permission
- Claude will show "Do you want to proceed?" prompt
- Icon should turn red
- Approve or deny → icon turns green

**Test multiple sessions:**
- Open Claude Code in multiple directories
- Each session appears in the dock menu
- Sessions with questions appear at the top
- Other sessions listed below

## Key Design Decisions

1. **Polling + FSEvents:** Combined approach for reliability
   - FSEvents catches most changes immediately
   - 2-second polling catches missed events
   - Ensures no missed state changes

2. **Tool execution detection:** Catches permission prompts
   - Permission prompts don't use AskUserQuestion
   - They appear as pending tool executions
   - Last message is tool_use without result

3. **Sound only on transition:** Prevents alert spam
   - Only play sound when green → red
   - Silent when staying red or red → green
   - Better user experience

4. **Right-click menu:** Better than hover tooltip
   - More reliable on macOS
   - Can show multiple sessions
   - Clickable actions (focus terminal)
   - Standard dock app pattern

## Future Enhancement Ideas

- [ ] Add preferences panel for customization
- [ ] Configurable colors/sounds
- [ ] Notification center integration
- [ ] Filter by session age (ignore old sessions)
- [ ] Deep link to specific terminal window
- [ ] Badge count showing number of waiting sessions
- [ ] Status bar mode (menu bar instead of dock)

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
