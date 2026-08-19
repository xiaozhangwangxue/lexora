#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h:h}
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/lexora-progress-build.XXXXXX")
APP_NAME="Lexora 采集进度.app"
APP_PATH="$BUILD_ROOT/$APP_NAME"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
INSTALL_DIR="$HOME/Applications"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME"
BACKUP_ROOT="$INSTALL_DIR/Lexora 采集进度备份"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
STAGING_PATH="$INSTALL_DIR/.Lexora-progress-$STAMP.app"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
OLD_APP_MOVED=0

mkdir -p "$MACOS" "$RESOURCES" "$INSTALL_DIR"

swiftc \
  -O \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework Combine \
  "$SCRIPT_DIR/LexoraProgressApp.swift" \
  -o "$MACOS/LexoraProgress"

cp "$SCRIPT_DIR/Info.plist" "$CONTENTS/Info.plist"
ICON_SOURCE="$PROJECT_ROOT/apps/lexora/assets/icon/lexora-icon.png"
ICONSET="$BUILD_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

codesign --force --deep --sign - "$APP_PATH"
plutil -lint "$CONTENTS/Info.plist"
codesign --verify --deep --strict "$APP_PATH"

# Prepare and verify the complete replacement beside the live app.  The live
# copy remains untouched if copying or verification fails.
ditto "$APP_PATH" "$STAGING_PATH"
codesign --verify --deep --strict "$STAGING_PATH"

restore_previous_app() {
  local status=$?
  if (( status != 0 && OLD_APP_MOVED == 1 )); then
    if [[ -e "$INSTALL_PATH" ]]; then
      mkdir -p "$BACKUP_DIR/failed-replacement"
      mv "$INSTALL_PATH" "$BACKUP_DIR/failed-replacement/$APP_NAME" || true
    fi
    mv "$BACKUP_DIR/$APP_NAME" "$INSTALL_PATH" || true
  fi
  exit $status
}
trap restore_previous_app EXIT

if [[ -e "$INSTALL_PATH" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$INSTALL_PATH" "$BACKUP_DIR/$APP_NAME"
  OLD_APP_MOVED=1
fi
mv "$STAGING_PATH" "$INSTALL_PATH"
codesign --verify --deep --strict "$INSTALL_PATH"
trap - EXIT

pkill -x LexoraProgress 2>/dev/null || true
for _ in {1..20}; do
  pgrep -x LexoraProgress >/dev/null 2>&1 || break
  sleep 0.1
done
open -n "$INSTALL_PATH"
echo "$INSTALL_PATH"
