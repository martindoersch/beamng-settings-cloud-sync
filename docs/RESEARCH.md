# BeamNG: syncing settings via Steam Cloud with a mod – research

As of: 2026-11-06

## What should be backed up (user folder)

User folder on Windows (default): `%LOCALAPPDATA%\BeamNG\BeamNG.drive\current`
(Launcher → "Manage User Folder" → "Open in Explorer")

| What | Where in the user folder |
|---|---|
| Game/menu settings | `settings/` |
| Keyboard/controller bindings | `settings/inputmaps/*.diff` |
| Custom vehicle configs | `vehicles/<model>/*.pc` (+ `.jpg` preview image) |

## Steam Cloud

- BeamNG already uses Steam Cloud to a small extent. According to SteamDB there is a rule for `…/BeamNG.drive/settings/cloud/**`, although the path still points to the old Documents folder. According to the official Steam Deck docs, "Settings and other user data" are synced.
- Exactly which files is not officially documented. Users reported in 2024 that key bindings are **not** carried over.
- Which folders are synced is defined by the developer in Steamworks. A mod cannot change that.
- Mods run in Lua with a virtual file system, so they only write to the user folder. A Steam Cloud API for mods is not documented.

## Open checks (on the Windows PC)

1. Does `settings/cloud/` exist in the user folder? What is in it?
2. Does `C:\Program Files (x86)\Steam\userdata\<SteamID>\284160\remote\` exist? What is in it?
3. Test: put a file into `settings/cloud/`, start and quit the game. Does it show up in Steam under Library → BeamNG → Properties (or on the second PC)?

## File system on Boosteroid (2026-11-09, BeamNG 0.40.5)

- **Two separate folders:**
  - `C:\Users\user\AppData\Local\BeamNG\BeamNG.drive\current\` is the normal user folder, local, empty in every session.
  - `C:\Users\user\AppData\Local\BeamNG\BeamNG.drive.cloud\` is the **Steam Cloud folder**. It contains `steam_autocloud.vdf` (Steam Auto-Cloud), `settings\`, `vehicles\`, `consoleHistory.json` and `deletedFiles.json`. BeamNG (`engine::Platform::CloudSaveData`) mirrors `settings/cloud/` and custom vehicle configs there; Steam only syncs this folder.
- `deletedFiles.json`: BeamNG keeps track of deleted files. Deleting in `settings/cloud/` therefore probably reaches the cloud as well (important for the history in v0.5).
- `BeamNG.drive.cloud\settings\cloud\` contains `missionProgress\`, `settingsCloudSync\`, `speedTrapLeaderboards\`, `cloudSyncTest.json` (left over from the test mod on 2026-11-06), `gameplay_stat.json`, `game-state.json`, **`mods-optout.json`** and `settings.json`.
- `settingsCloudSync\` contains `files\`, `config.json` and `manifest.json`. Under `files\settings\` are `inputmaps\`, `ui_apps\` (UI layouts), `freeroamConfigurator.json`, `freeroamSelectorData.json`, `game-settings.json`, `imgui.ini`, `imguiSettings.json`, `settings.json` and `vehicleSelectorData.json`.
- `BeamNG.drive\current\mods\` contains `repo\` and `db.json`, **local only**. This confirms: installed mods and their active state do not survive the session.
- `mods\repo\settings_cloud_sync_martindoersch.zip` is **1,471 KB**, our zip only about 17 KB. The repository server apparently adds the icon and images.
- `mods-optout.json` only contains `{}` (read via console, 2026-11-09). It was written at 19:57, at the same time as `mods\db.json`, i.e. when the mod was activated. Assumption: an opt-out list for a mod sync, currently empty. **Result (2026-11-09):** the mod was subscribed ("Subscribed: You get automatic updates") and still gone after the new session. Subscribing does not bring it back on Boosteroid.
- The game console runs as `GELua(Sandboxed)`.
- Content of `manifest.json` (v0.3, Boosteroid, 2026-11-09): `backupId = "20261109194947-3660"`. `controls` only contains **`/settings/inputmaps/xidevice.diff`** (Xbox controller), no `keyboard.diff`. `otherSettings` contains `freeroamConfigurator.json`, `freeroamSelectorData.json`, `game-settings.json`, `imgui.ini`, `imguiSettings.json`, `settings.json`, `ui_apps/…` etc. There is only a date per category (`created`), no machine name. This matches the fallback in v0.5 (`manifestCreated`, "unknown PC").
- The icon exists on the server (`attachments/icon_96-png.1351973`). The info area of the mod manager still shows a generic cube.
- Original question: what is in `mods-optout.json`? Assumption: an opt-out list for a mod sync (e.g. repository subscriptions via the BeamNG account). If so, searching for the mod in every session could perhaps be avoided. Read it via the console: `dump(jsonReadFile('/settings/cloud/mods-optout.json'))`

## Modding basics

- Mod = zip in `mods/`, structure mirrors the game folder
- Lua extension: `lua/ge/extensions/<name>.lua` returns a table `M`
- UI app (buttons in game): `ui/modules/apps/<name>/`
- Docs: https://documentation.beamng.com/modding/programming/extensions/
