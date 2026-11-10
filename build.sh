#!/bin/sh
# Packs the mods as zip files into dist/
set -e
cd "$(dirname "$0")"
mkdir -p dist

# The version shown in the UI (Lua) must match app.json
v_lua=$(sed -n "s/^local version = '\(.*\)'.*/\1/p" mods/SettingsCloudSync/lua/ge/extensions/settingsCloudSync.lua)
v_app=$(sed -n 's/.*"version": "\(.*\)".*/\1/p' mods/SettingsCloudSync/ui/modules/apps/SettingsCloudSync/app.json)
[ -n "$v_lua" ] && [ "$v_lua" = "$v_app" ] || { echo "Version mismatch: Lua '$v_lua', app.json '$v_app'" >&2; exit 1; }
echo "Building version $v_lua"

build() { # build <Quellordner> <zip-Name>
  rm -f "dist/$2.zip"
  (cd "$1" && zip -r "$OLDPWD/dist/$2.zip" lua scripts $(ls -d ui 2>/dev/null) -x '*.DS_Store')
}

build mods/SettingsCloudSync settings_cloud_sync_martindoersch
build mods/CloudSyncTest cloudSyncTest
