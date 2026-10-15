#!/bin/bash
set -e

swift build -c release

APP_NAME="SleeplessClone.app"
CONTENTS="$APP_NAME/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_NAME"
mkdir -p "$MACOS"

cp .build/release/SleeplessClone "$MACOS/SleeplessClone"

cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SleeplessClone</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.SleeplessClone</string>
    <key>CFBundleName</key>
    <string>SleeplessClone</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Successfully built $APP_NAME"
