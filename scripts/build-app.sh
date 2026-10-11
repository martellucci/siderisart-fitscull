#!/bin/zsh
# Compila in release, crea FitsCull.app, firma ad-hoc e installa nella destinazione.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${1:-/Volumes/Dati2/applicazioni}"
[[ -d "$DEST" ]] || { echo "Destinazione non trovata: $DEST" >&2; exit 1; }

swift build -c release --product FitsCull
BIN="$(swift build -c release --show-bin-path)/FitsCull"
[[ -f build/AppIcon.icns ]] || scripts/make-icon.sh

APP=build/FitsCull.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FitsCull"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

rm -rf "$DEST/FitsCull.app"
cp -R "$APP" "$DEST/"
echo "Installata: $DEST/FitsCull.app"
