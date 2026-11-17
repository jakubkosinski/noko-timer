#!/bin/bash
# Renders Design/AppIcon.svg into the app icon asset catalog. Requires: brew install librsvg
set -euo pipefail
cd "$(dirname "$0")/.."
SET=NokoBar/Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p "$SET"
for n in 16 32 64 128 256 512 1024; do
  rsvg-convert -w $n -h $n Design/AppIcon.svg -o "$SET/icon_$n.png"
done
cat > NokoBar/Resources/Assets.xcassets/Contents.json <<'JSON'
{ "info": { "author": "xcode", "version": 1 } }
JSON
cat > "$SET/Contents.json" <<'JSON'
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "16x16",   "filename": "icon_16.png" },
    { "idiom": "mac", "scale": "2x", "size": "16x16",   "filename": "icon_32.png" },
    { "idiom": "mac", "scale": "1x", "size": "32x32",   "filename": "icon_32.png" },
    { "idiom": "mac", "scale": "2x", "size": "32x32",   "filename": "icon_64.png" },
    { "idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128.png" },
    { "idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_256.png" },
    { "idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256.png" },
    { "idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_512.png" },
    { "idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512.png" },
    { "idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_1024.png" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
JSON
echo "Icon generated in $SET"
