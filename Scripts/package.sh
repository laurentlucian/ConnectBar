#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/release"
APP="$ROOT/build/ConnectBar.app"

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/ConnectBar" "$APP/Contents/MacOS/ConnectBar"
swift "$ROOT/Scripts/generate-icon.swift" "$ROOT/Assets/ConnectBar.png" "$APP/Contents/Resources/ConnectBar.icns"
sed "s/CONNECTBAR_VERSION/${CONNECTBAR_VERSION:-0.1.0}/g" "$ROOT/Scripts/Info.plist" > "$APP/Contents/Info.plist"
codesign --force --deep --sign "${CONNECTBAR_SIGNING_IDENTITY:--}" "$APP"
echo "$APP"
