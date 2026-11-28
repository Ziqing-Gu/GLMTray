#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${1:?Pass a build output directory}"
out="$(cd "$1" && pwd)"
tmp="$(mktemp -d "$out/package.XXXXXX")"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/macos/Info.plist")
app="$tmp/payload/GLM Tray.app"
res="$app/Contents/Resources"
mkdir -p "$app/Contents/MacOS" "$res" "$tmp/GLMTray.iconset"
cp "$root/macos/Info.plist" "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"
xcrun clang -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 -fobjc-arc -fblocks -O2 \
  -Wall -Wextra -Werror -Wno-unused-parameter "$root/macos/App.m" "$root/macos/GLMController.m" \
  -framework AppKit -framework ServiceManagement -framework UniformTypeIdentifiers -o "$app/Contents/MacOS/GLMTray"
strip -x "$app/Contents/MacOS/GLMTray"
# The shared Windows icon contains a lossless 256 px PNG of the original green monitor.
python3 - "$root/native/GLMTray.ico" "$tmp/master.png" <<'PY'
from pathlib import Path
import struct, sys
ico = Path(sys.argv[1]).read_bytes()
for i in range(struct.unpack_from('<H', ico, 4)[0]):
    width, height, _, _, _, _, size, offset = struct.unpack_from('<BBBBHHII', ico, 6 + i * 16)
    if width == height == 0 and ico[offset:offset+8] == bytes.fromhex('89504e470d0a1a0a'):
        Path(sys.argv[2]).write_bytes(ico[offset:offset+size])
        break
else:
    raise SystemExit('Missing 256 px source icon')
PY
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$tmp/master.png" --out "$tmp/GLMTray.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size*2))" "$((size*2))" "$tmp/master.png" --out "$tmp/GLMTray.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$tmp/GLMTray.iconset" -o "$res/GLMTray.icns"
cp "$root/LICENSE" "$root/docs/Install-ZH.md" "$root/docs/Install-EN.md" "$root/docs/GLMTray-Quick-Start.txt" "$res/"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --strict --all-architectures "$app"
lipo "$app/Contents/MacOS/GLMTray" -verify_arch arm64 x86_64
pkgbuild --analyze --root "$tmp/payload" "$tmp/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$tmp/components.plist"
pkg="$out/GLMTray-$version-macOS-Universal.pkg"
pkgbuild --root "$tmp/payload" --component-plist "$tmp/components.plist" --install-location /Applications \
  --identifier org.qingaudio.GLMTray.pkg --version "$version" --ownership recommended "$pkg"
shasum -a 256 "$pkg"
