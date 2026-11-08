#!/bin/sh
# Re-renders the app icon PNG from Design/AppIcon.svg. App icons must not have an alpha channel,
# so the Quick Look render is flattened through JPEG before landing in the asset catalog.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
qlmanage -t -s 1024 -o "$tmp" Design/AppIcon.svg >/dev/null
sips -s format jpeg -s formatOptions 100 "$tmp/AppIcon.svg.png" --out "$tmp/AppIcon.jpg" >/dev/null
sips -s format png "$tmp/AppIcon.jpg" --out DuoFoldControl/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
rm -rf "$tmp"
