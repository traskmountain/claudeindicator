# ClaudeIndicator

A macOS dock app that monitors all Claude Code sessions and provides real-time visual feedback when Claude is waiting for your input.

## Features

### Visual Indicators
- **Green dock icon**: All sessions are idle or working normally
- **Red dock icon**: At least one session is waiting for your input
- **Sound alert**: Plays a notification sound when state changes to red
- **Session markers**: Right-click menu shows which sessions need attention
  - 🔴 User prompt waiting for Claude's response
  - ⏸ Tool execution pending (permission prompt)
  - ❓ AskUserQuestion waiting for answer

### Smart Session Management
- **Configurable time window**: Only monitor recent sessions (default: 1 hour)
  - Presets: 5 min, 15 min, 30 min, 1 hour, 4 hours, 1 day
  - Prevents old/stale sessions from keeping indicator red
- **Multi-session support**: Monitors ALL active Claude Code sessions
- **Manual refresh**: Force immediate rescan with ⌘R
- **Window focusing**: Click a session to bring its terminal window to front

### Automation
- **Auto-start**: Configure to launch on login
- **Fast polling**: 0.5-second update cycle for responsive feedback

## How It Works

The app monitors `~/.claude/projects/` for `.jsonl` session files and detects three types of waiting states:
1. **AskUserQuestion**: Claude explicitly asked a question
2. **Tool pending**: Tool execution waiting for approval
3. **User prompt**: Your message waiting for Claude's response

Only sessions modified within your configured time window are monitored, preventing false positives from old sessions.

## Building

```bash
cd ClaudeIndicator
chmod +x build.sh
./build.sh
```

This will create `build/ClaudeIndicator.app`

## Running

```bash
open build/ClaudeIndicator.app
```

The app will appear in your dock with a green icon (with a "C" symbol).

## Installing as Login Item

To make the app start automatically when you log in:

```bash
chmod +x install-login-item.sh
./install-login-item.sh
launchctl load ~/Library/LaunchAgents/com.claudecode.indicator.plist
```

## Uninstalling

```bash
launchctl unload ~/Library/LaunchAgents/com.claudecode.indicator.plist
rm ~/Library/LaunchAgents/com.claudecode.indicator.plist
```

## Requirements

- macOS 11.0 (Big Sur) or later
- Swift compiler (comes with Xcode Command Line Tools)

## Usage

### Basic Operation
1. Start ClaudeIndicator - it appears in your dock with a green "C" icon
2. Work normally with Claude Code in any terminal
3. When Claude needs input:
   - Dock icon turns red
   - Sound alert plays (optional)
4. Right-click the dock icon to see:
   - Which sessions have questions (with emoji indicators)
   - Click a session to focus its terminal window
   - Access Preferences to adjust time window
   - Manually refresh sessions with "Refresh Sessions" (⌘R)

### Configuring Time Window
1. Right-click the dock icon
2. Go to **Preferences** → **Session Time Window**
3. Select your preferred window (5 min to 1 day)
4. Sessions older than this window will be ignored

### Tips
- **Too many red alerts?** Reduce the time window to 5 or 15 minutes
- **Missing sessions?** Increase the time window or click "Refresh Sessions"
- **Focus not working?** Ensure your terminal window title contains the project name

## Architecture

- **main.swift**: App entry point, UI management, and dock menu
- **ClaudeSessionMonitor.swift**: Session orchestration with time-based filtering
- **DirectoryWatcher.swift**: File system watcher using DispatchSource
- **JSONLParser.swift**: Parses JSONL files and tracks session state
- **DockIconGenerator.swift**: Generates green/red dock icons dynamically
- **SoundManager.swift**: Plays alert sounds on state transitions
- **SettingsManager.swift**: UserDefaults-based preferences storage

## Troubleshooting

**Icon always red:**
- Old sessions may have pending states - adjust time window to 15-30 minutes
- Archive old sessions: `mkdir -p ~/.claude/projects-archive && find ~/.claude/projects -name "*.jsonl" -mtime +7 -exec mv {} ~/.claude/projects-archive/ \;`
- Use "Refresh Sessions" to force a rescan

**Icon never turns red:**
- Check that `~/.claude/projects/` exists and contains `.jsonl` files
- Verify sessions are within the configured time window
- Check Console.app for errors: `log stream --predicate 'process == "ClaudeIndicator"' --level debug`

**Window focusing doesn't work:**
- Ensure terminal window title contains the project directory name
- Check that you're using Terminal.app or iTerm2
- Grant accessibility permissions in System Preferences → Privacy & Security
