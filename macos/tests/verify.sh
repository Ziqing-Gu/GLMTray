#!/bin/bash
# Run on a clean macOS test account. Installation verification uses a disposable GitHub-hosted runner.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
pkg="${1:?Pass the Universal PKG}"
mkdir -p "${2:?Pass an empty output directory}"
work="$(cd "$2" && pwd)"
app="/Applications/GLM Tray.app"
if [[ -e "$app" ]]; then echo "Use a clean test Mac with no installed copy of GLM Tray." >&2; exit 2; fi
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/macos/Info.plist")
pkgutil --expand-full "$pkg" "$work/expanded"
python3 - "$work/expanded/PackageInfo" "$version" <<'PY'
import sys
from xml.etree import ElementTree as ET
p = ET.parse(sys.argv[1]).getroot()
assert p.get('identifier') == 'org.qingaudio.GLMTray.pkg' and p.get('version') == sys.argv[2]
assert p.get('install-location') == '/Applications'
assert p.find('scripts') is None or not list(p.find('scripts'))
PY
sudo -n /usr/sbin/installer -pkg "$pkg" -target /
pkgutil --pkg-info org.qingaudio.GLMTray.pkg
codesign --verify --strict --all-architectures "$app"
lipo "$app/Contents/MacOS/GLMTray" -verify_arch arm64 x86_64
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$app/Contents/Info.plist")" == "true" ]]
for file in Install-ZH.md Install-EN.md GLMTray-Quick-Start.txt; do cmp "$root/docs/$file" "$app/Contents/Resources/$file"; done
cmp "$root/LICENSE" "$app/Contents/Resources/LICENSE"
cmp "$work/expanded/Payload/GLM Tray.app/Contents/MacOS/GLMTray" "$app/Contents/MacOS/GLMTray"
fixture="$work/GLMv5.app"
mkdir -p "$fixture/Contents/MacOS"
python3 - "$fixture/Contents/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
    plistlib.dump(dict(CFBundleIdentifier='org.qingaudio.GLMTray.IntegrationFixture', CFBundleName='GLMv5',
        CFBundleExecutable='GLMv5', CFBundlePackageType='APPL',CFBundleVersion='1', NSPrincipalClass='NSApplication'),f)
PY
flags=(-mmacosx-version-min=13.0 -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter)
xcrun clang "${flags[@]}" "$root/macos/tests/Fixture.m" -framework AppKit -o "$fixture/Contents/MacOS/GLMv5"
codesign --force --sign - "$fixture"
xcrun clang "${flags[@]}" "$root/macos/tests/Integration.m" "$root/macos/GLMController.m" -framework AppKit -o "$work/integration"
/usr/bin/lsappinfo info -only name -app Finder || true
"$work/integration" "$fixture" "$app" "$work/functional.json"
python3 - "$pkg" "$app" "$work/functional.json" <<'PY'
import hashlib,json,os,platform,subprocess,sys
from pathlib import Path
pkg,app,record=map(Path,sys.argv[1:])
exe=app/'Contents/MacOS/GLMTray'
data=json.loads(record.read_text())
data.update(runner=platform.machine(),slices=subprocess.check_output(['lipo','-archs',str(exe)],text=True).split(),
    package=pkg.name,bytes=pkg.stat().st_size,sha256=hashlib.sha256(pkg.read_bytes()).hexdigest(),
    executableSHA256=hashlib.sha256(exe.read_bytes()).hexdigest(),installedPath=str(app),signature='ad-hoc app; unsigned PKG; not notarized')
record.write_text(json.dumps(data,indent=2)+'\n')
print(record.read_text())
PY
