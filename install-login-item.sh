#!/bin/bash

# Install ClaudeIndicator as a login item

set -e

APP_NAME="ClaudeIndicator.app"
BUILD_DIR="build"
APP_PATH="$(pwd)/$BUILD_DIR/$APP_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claudecode.indicator.plist"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Please run ./build.sh first"
    exit 1
fi

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# Create the LaunchAgent plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claudecode.indicator</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-a</string>
        <string>$APP_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

echo "LaunchAgent installed at: $PLIST_PATH"
echo ""
echo "To start the app now:"
echo "  launchctl load $PLIST_PATH"
echo ""
echo "To stop the app:"
echo "  launchctl unload $PLIST_PATH"
echo ""
echo "The app will automatically start on next login."
