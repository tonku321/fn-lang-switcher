#!/bin/bash
set -e

APP_NAME="FnLangSwitch"
APP_BUNDLE=".build/$APP_NAME.app"

# Build release
swift build -c release

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy universal executable
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Sources/$APP_NAME/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Generate icon
cat > /tmp/gen_icon.swift << 'EOF'
import AppKit
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let bgRect = NSRect(x: 40, y: 40, width: size - 80, height: size - 80)
NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0).setFill()
NSBezierPath(roundedRect: bgRect, xRadius: 180, yRadius: 180).fill()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 420, weight: .bold),
    .foregroundColor: NSColor.white,
]
let text = "Fn" as NSString
let textSize = text.size(withAttributes: attrs)
text.draw(at: NSPoint(
    x: (CGFloat(size) - textSize.width) / 2,
    y: (CGFloat(size) - textSize.height) / 2
), withAttributes: attrs)
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: "/tmp/fnlangswitch_icon.png"))
EOF
swift /tmp/gen_icon.swift

# Convert PNG to icns
ICONSET="/tmp/$APP_NAME.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512 1024; do
    sips -z $s $s /tmp/fnlangswitch_icon.png --out "$ICONSET/icon_${s}x${s}.png" > /dev/null 2>&1
done
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png"
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Cleanup temp files
rm -rf "$ICONSET" /tmp/fnlangswitch_icon.png /tmp/gen_icon.swift

# Ad-hoc sign
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
file "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo ""
echo "Install: cp -R $APP_BUNDLE /Applications/"
