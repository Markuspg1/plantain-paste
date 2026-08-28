#!/bin/bash
# Builds PBP in release mode and assembles a signed (ad-hoc) .app bundle
# at build/PBP.app. Drag it to /Applications when you're happy with it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/PBP.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/PBP "$APP/Contents/MacOS/PBP"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# If the checkout lives in an iCloud Drive folder, the file provider stamps
# xattrs (com.apple.fileprovider.*, FinderInfo) that invalidate the signature.
xattr -cr "$APP"
codesign --force --sign - "$APP"

echo "Built $APP"

# ./make-app.sh --install copies it to /Applications and re-signs there,
# so Finder-drag xattr problems can't happen.
if [[ "${1:-}" == "--install" ]]; then
    if pgrep -x PBP >/dev/null; then
        echo "Quitting running PBP…"
        pkill -x PBP || true
        sleep 1
    fi
    rm -rf /Applications/PBP.app
    ditto "$APP" /Applications/PBP.app
    xattr -cr /Applications/PBP.app
    codesign --force --sign - /Applications/PBP.app
    codesign -v --strict /Applications/PBP.app
    echo "Installed /Applications/PBP.app"
    open /Applications/PBP.app
fi
