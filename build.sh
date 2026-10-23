#!/bin/bash
# Builds build/Hush.app (ad-hoc signed). Needs only the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Hush.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -sdk "${SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}" -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
    Sources/*.swift -o "$APP/Contents/MacOS/Hush"

cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --sign - "$APP"
echo "Built $APP"
