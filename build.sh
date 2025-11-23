#!/bin/bash

# Build script for ClaudeIndicator macOS app

set -e

echo "Building ClaudeIndicator..."

# Create app bundle structure
APP_NAME="ClaudeIndicator.app"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile Swift files
echo "Compiling Swift sources..."
ARCH=$(uname -m)
swiftc \
    -o "$MACOS_DIR/ClaudeIndicator" \
    -target ${ARCH}-apple-macos11.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework Cocoa \
    -framework AppKit \
    -framework Foundation \
    -framework AVFoundation \
    -framework AudioToolbox \
    ClaudeIndicator/*.swift

# Copy Info.plist
cp ClaudeIndicator/Info.plist "$CONTENTS_DIR/"

echo "Build complete: $APP_DIR"
echo ""
echo "To run the app:"
echo "  open $APP_DIR"
echo ""
echo "To install as login item:"
echo "  ./install-login-item.sh"
