#!/usr/bin/env bash
# Builds "TimeBridge Bar.app" from the native Swift sources using Apple's Swift
# compiler (comes with Xcode or the Command Line Tools — no third party).
set -euo pipefail
cd "$(dirname "$0")"

APP="TimeBridge Bar.app"
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TimeBridge Bar</string>
  <key>CFBundleDisplayName</key><string>TimeBridge Bar</string>
  <key>CFBundleIdentifier</key><string>local.timebridge.bar</string>
  <key>CFBundleExecutable</key><string>TimeBridgeBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

swiftc -O *.swift -o "$APP/Contents/MacOS/TimeBridgeBar"

echo "Built: $(pwd)/$APP"
echo "Run it with:   open \"$APP\""
echo "Start at login: System Settings → General → Login Items → + → select the app."
