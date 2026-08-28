#!/bin/bash
# Builds Plantain Paste in release mode and assembles a signed (ad-hoc) .app
# bundle at "build/Plantain Paste.app".
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Plantain Paste.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/PlantainPaste "$APP/Contents/MacOS/PlantainPaste"
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
    if pgrep -x PlantainPaste >/dev/null; then
        echo "Quitting running Plantain Paste…"
        pkill -x PlantainPaste || true
        sleep 1
    fi
    rm -rf "/Applications/Plantain Paste.app"
    ditto "$APP" "/Applications/Plantain Paste.app"
    xattr -cr "/Applications/Plantain Paste.app"
    codesign --force --sign - "/Applications/Plantain Paste.app"
    codesign -v --strict "/Applications/Plantain Paste.app"
    echo "Installed /Applications/Plantain Paste.app"
    open "/Applications/Plantain Paste.app"
fi
