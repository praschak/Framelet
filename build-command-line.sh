#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
    echo 'This project must be built on macOS.' >&2
    exit 1
fi
xcrun --find swift >/dev/null
swift package resolve
# These are design-time Xcode previews, not needed for the standalone app.
preview_file=".build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Recorder.swift"
chmod u+w "$preview_file"
python3 - "$preview_file" <<'PYCODE'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = re.sub(r"#Preview \{\n[^}]*\n\}\n", "", s)
p.write_text(s)
PYCODE
# SwiftPM's generated resource lookup can look outside Contents/Resources.
# Patch the pinned dependency to use the signed app's resource bundle first.
utilities_file=".build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Utilities.swift"
chmod u+w "$utilities_file"
python3 - "$utilities_file" <<'PYCODE'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'NSLocalizedString(self, bundle: .module, comment: self)'
new = 'NSLocalizedString(self, bundle: .frameletKeyboardResources, comment: self)'
if old in s:
    s = s.replace(old, new)
    marker = 'import SwiftUI\n'
    if s.count(marker) != 1:
        raise SystemExit('Unexpected KeyboardShortcuts source; cannot patch resource lookup.')
    helper = '''
private extension Bundle {
    static let frameletKeyboardResources: Bundle = {
        if let url = Bundle.main.url(forResource: "KeyboardShortcuts_KeyboardShortcuts", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()
}
'''
    s = s.replace(marker, marker + helper, 1)
    p.write_text(s)
elif new not in s:
    raise SystemExit('Unexpected KeyboardShortcuts source; cannot patch resource lookup.')
PYCODE
if [[ -n "${FRAMELET_SDK_PATH:-}" ]]; then
    sdk_path="$FRAMELET_SDK_PATH"
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    # The standalone CLT 27 SDK can lack SwiftUI's macro plugins.
    sdk_path=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
else
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
fi
build_args=(-c release --sdk "$sdk_path")
if [[ "${FRAMELET_UNIVERSAL:-0}" == 1 ]]; then
    build_args+=(--arch arm64 --arch x86_64)
fi
swift build "${build_args[@]}"
binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
app="$PWD/build/Framelet.app"
if [[ -e "$app" ]]; then
    echo "Move the existing $app aside before building a fresh bundle." >&2
    exit 1
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Framelet" "$app/Contents/MacOS/Framelet"
# Architecture check skipped for local development.
cp "Framelet/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "Framelet/PrivacyInfo.xcprivacy" "$app/Contents/Resources/PrivacyInfo.xcprivacy"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Framelet</string>
<key>CFBundleIdentifier</key><string>app.framelet.recorder</string>
<key>CFBundleName</key><string>Framelet</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDisplayName</key><string>Framelet</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Framelet records your microphone alongside the selected window.</string>
<key>NSAudioCaptureUsageDescription</key><string>Framelet records system audio alongside the selected window.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
bundle_path="$(find .build -type d -name 'KeyboardShortcuts_KeyboardShortcuts.bundle' -print -quit)"
if [[ -z "$bundle_path" ]]; then
    echo 'KeyboardShortcuts resource bundle not found.' >&2
    exit 1
fi
ditto "$bundle_path" "$app/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
codesign --force --sign - --entitlements Framelet/Framelet.entitlements "$app"
if ! codesign --verify --deep --strict "$app"; then
    echo 'Error: macOS did not validate the app signature.' >&2
    exit 1
fi
echo "Built: $app"
echo "Launch with: open \"$app\""
