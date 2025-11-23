# ClaudeIndicator

A macOS dock app that monitors all Claude Code sessions and changes color based on whether Claude is asking you a question.

## Features

- **Green dock icon**: Claude is idle or working
- **Red dock icon**: Claude is asking you a question (via AskUserQuestion)
- **Sound alert**: Plays a notification sound when Claude asks a question
- **Multi-session support**: Monitors ALL Claude Code sessions on your system
- **Auto-start**: Can be configured to launch on login

## How It Works

The app monitors `~/.claude/projects/` for all `.jsonl` session files and parses them in real-time to detect when Claude uses the `AskUserQuestion` tool. When any active session has an unanswered question, the dock icon turns red and plays an alert sound.

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

## Testing

1. Start the ClaudeIndicator app
2. Open a Claude Code session
3. Trigger an AskUserQuestion (Claude will ask you something)
4. Watch the dock icon turn red and hear the alert sound
5. Answer the question in Claude Code
6. Watch the icon turn back to green

## Architecture

- **main.swift**: App entry point and delegation
- **ClaudeSessionMonitor.swift**: Orchestrates monitoring of all sessions
- **DirectoryWatcher.swift**: File system watcher using DispatchSource
- **JSONLParser.swift**: Parses JSONL files to detect questions
- **DockIconGenerator.swift**: Generates green/red dock icons
- **SoundManager.swift**: Plays alert sounds

## Troubleshooting

If the app doesn't detect questions:
- Check that `~/.claude/projects/` exists and contains `.jsonl` files
- Verify the app has permission to read your home directory
- Check Console.app for any error messages from ClaudeIndicator
