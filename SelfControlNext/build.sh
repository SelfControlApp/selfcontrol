#!/bin/bash
# Builds SelfControl (Next) into build/SelfControl.app. Needs only the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/SelfControl.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/SelfControlNext" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp ../SelfControlIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
echo "Built $PWD/$APP"
