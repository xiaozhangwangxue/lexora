#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <Lexora.app> <background.png> <output.dmg>" >&2
  exit 2
fi

APP_PATH="$1"
BACKGROUND_PATH="$2"
OUTPUT_PATH="$3"
LAYOUT_PATH="$(dirname "$BACKGROUND_PATH")/dmg-layout.DS_Store"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ ! -f "$BACKGROUND_PATH" ]]; then
  echo "DMG background not found: $BACKGROUND_PATH" >&2
  exit 1
fi
if [[ ! -f "$LAYOUT_PATH" ]]; then
  echo "DMG Finder layout not found: $LAYOUT_PATH" >&2
  exit 1
fi
if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$PWD/$OUTPUT_PATH"
fi

WORK_DIRECTORY="$(mktemp -d)"
STAGING_DIRECTORY="$WORK_DIRECTORY/staging"
cleanup() {
  rm -rf "$WORK_DIRECTORY"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIRECTORY/.background" "$(dirname "$OUTPUT_PATH")"
ditto "$APP_PATH" "$STAGING_DIRECTORY/Lexora.app"
ln -s /Applications "$STAGING_DIRECTORY/Applications"
cp "$BACKGROUND_PATH" "$STAGING_DIRECTORY/.background/dmg-background.png"
cp "$LAYOUT_PATH" "$STAGING_DIRECTORY/.DS_Store"

hdiutil create \
  -quiet \
  -volname "Lexora" \
  -srcfolder "$STAGING_DIRECTORY" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$OUTPUT_PATH"

echo "Created $OUTPUT_PATH"
