#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
xcrun swift build --disable-sandbox --cache-path .build/package-cache --scratch-path .build/swiftpm -c release
app_path="$PWD/build/Zoom Caption Saver.app"
mkdir -p "$app_path/Contents/MacOS"
cp .build/swiftpm/release/ZoomCaptionSaver "$app_path/Contents/MacOS/ZoomCaptionSaver"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.zoom-caption-saver</string>
<key>CFBundleName</key><string>Zoom Caption Saver</string>
<key>CFBundleDisplayName</key><string>Zoom Caption Saver</string>
<key>CFBundleExecutable</key><string>ZoomCaptionSaver</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.zoom-caption-saver "$app_path"
printf 'Built %s\n' "$app_path"
