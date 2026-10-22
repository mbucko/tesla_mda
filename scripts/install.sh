#!/bin/zsh
# Builds TeslaMDA.app and installs it to ~/Applications (required for Launch at Login).
set -euo pipefail

cd "$(dirname "$0")/.."
APP="$HOME/Applications/TeslaMDA.app"

swift build -c release
pkill -x TeslaMDA || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TeslaMDA "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"

open "$APP"
echo "Installed $APP"
