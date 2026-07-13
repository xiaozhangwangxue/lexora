#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <Lexora.app> <background.png> <output.dmg>" >&2
  exit 2
fi

APP_PATH="$1"
BACKGROUND_PATH="$2"
OUTPUT_PATH="$3"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ ! -f "$BACKGROUND_PATH" ]]; then
  echo "DMG background not found: $BACKGROUND_PATH" >&2
  exit 1
fi
if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$PWD/$OUTPUT_PATH"
fi

WORK_DIRECTORY="$(mktemp -d)"
STAGING_DIRECTORY="$WORK_DIRECTORY/staging"
READ_WRITE_DMG="$WORK_DIRECTORY/Lexora-read-write.dmg"
BUILD_VOLUME_NAME="Lexora Package $$"
MOUNT_DEVICE=""
cleanup() {
  if [[ -n "$MOUNT_DEVICE" ]]; then
    hdiutil detach "$MOUNT_DEVICE" -quiet -force >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIRECTORY"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIRECTORY/.background" "$(dirname "$OUTPUT_PATH")"
ditto "$APP_PATH" "$STAGING_DIRECTORY/Lexora.app"
ln -s /Applications "$STAGING_DIRECTORY/Applications"
cp "$BACKGROUND_PATH" "$STAGING_DIRECTORY/.background/dmg-background.png"

hdiutil create \
  -quiet \
  -volname "$BUILD_VOLUME_NAME" \
  -srcfolder "$STAGING_DIRECTORY" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$READ_WRITE_DMG"

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify "$READ_WRITE_DMG")"
MOUNT_DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"
MOUNT_DIRECTORY="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/Apple_HFS/ {print $NF; exit}')"

if [[ -z "$MOUNT_DEVICE" || -z "$MOUNT_DIRECTORY" ]]; then
  echo "Unable to mount writable DMG" >&2
  exit 1
fi

sleep 1

# Finder must write the layout into the mounted volume. Copying a prebuilt
# .DS_Store is unreliable because Finder may ignore or replace it when the
# volume identifier changes during packaging.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$BUILD_VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set bounds of container window to {120, 120, 720, 522}

    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 14
    set background picture of viewOptions to file ".background:dmg-background.png"

    set position of item "Lexora.app" of container window to {155, 190}
    set position of item "Applications" of container window to {445, 190}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
sleep 2
diskutil rename "$MOUNT_DEVICE" "Lexora" >/dev/null
sync
sleep 1
if ! hdiutil detach "$MOUNT_DEVICE" -quiet; then
  hdiutil detach "$MOUNT_DEVICE" -quiet -force
fi
MOUNT_DEVICE=""

hdiutil convert \
  "$READ_WRITE_DMG" \
  -quiet \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$OUTPUT_PATH"

echo "Created $OUTPUT_PATH"
