#!/bin/zsh
# Genera build/AppIcon.icns da scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/AppIcon.iconset
mkdir -p build/AppIcon.iconset
swift scripts/make-icon.swift build/icon-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  d=$((s * 2))
  sips -z $d $d build/icon-1024.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
echo "Icona: build/AppIcon.icns"
