#!/bin/bash
# Build RadioBar.app bundle from the SPM executable
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

APP="$DIR/dist/RadioBar.app"
CONTENTS="$APP/Contents"

# Build release binary
echo "Building..."
swift build -c release --quiet

# Create .app structure
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# Copy binary
cp .build/release/RadioBar "$CONTENTS/MacOS/RadioBar"

# Convert icon.png to .icns
if [ -f icon.png ]; then
    echo "Creating icon..."
    ICONSET=$(mktemp -d)/RadioBar.iconset
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
    done
    for size in 32 64 256 512 1024; do
        half=$((size / 2))
        sips -z $size $size icon.png --out "$ICONSET/icon_${half}x${half}@2x.png" >/dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET")"
fi

# Write Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RadioBar</string>
    <key>CFBundleDisplayName</key>
    <string>RadioBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.radiobar.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>RadioBar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

echo "Built: $APP"
