# Development notes – Settings Cloud Sync (mod)

Goal: take menu settings, key bindings and custom vehicle configs along via Steam Cloud, e.g. for BeamNG on Boosteroid. The mod is meant for the official BeamNG repository, because on Boosteroid mods can only be installed from there.

## Folders

| Path | Content |
|---|---|
| `mods/SettingsCloudSync/` | Source of the actual mod (Lua extension + UI app with profiles, category selection, export/import, auto-import) |
| `mods/CloudSyncTest/` | Diagnostic mod (testing only, not for the repository) |
| `dist/` | Finished zip files, built with `./build.sh` (not in Git) |
| `docs/RESEARCH.md` | User folder, Steam Cloud, modding basics, repository API |
| `tests/` | Logic tests against a mocked BeamNG (Node.js + fengari), see README |
| `CHANGELOG.md` | Changes per version |
| `docs/TEST.md` | Console tests and results |
| `docs/REPOSITORY.md` | Repository submission and description text |
| `grafik/` | Icon (512×512) and repository graphics per version: `v0.x/svg/` (editable in Affinity) and `v0.x/png/`. Each version folder holds the full set used for that upload. App graphic: `python3 grafik/make_app_svg.py grafik/v0.6/svg`, PNG via Chrome headless at 1920×1080. English only |
| `Screenshots/` | Test results (local only, not in Git) |

## Status (2026-11-06)

Console test on Boosteroid, BeamNG 0.40.4:

- The game has its own module `engine::Platform::CloudSaveData`. It copies files from `settings/cloud/` to the Steam Cloud **immediately**. According to the log our test file was uploaded too ("Copying from local to cloud: settings\cloud\cloudSyncTest.json").
- `settings/cloud/` already contains `settings.json`, `game-state.json`, mission progress etc. **BeamNG already syncs the menu settings itself.**
- **BeamNG also syncs vehicle configs itself:** when saving `md gavril.pc` the log said "Copying from local to cloud: vehicles\pickup\md gavril.pc" (plus `info_…json`). The game keeps the list of synced files in `knownFiles.json` in the user folder.
- **BeamNG does not sync key bindings:** with the filter `CloudSaveData` there was no line about `inputmaps` after rebinding. The 11 entries in `knownFiles.json` are fully explained by `settings/cloud/` (8), `md gavril.pc` and `info_…json` (2) and `consoleHistory.json` (1).
- Dry run v0.2 successful: `FS:getFileRealPath` and `FS:findFiles` with a pattern work. Found: 1 input map, 1 custom config and 16 files under `/settings/`.
- The Lua functions `FS:directoryExists`, `FS:findFiles`, `jsonReadFile`, `jsonWriteFile` and `FS:getUserPath` work without errors.
- Test 2 showed `LOCAL=2`, but probably ran in the same session.
- **Test 5 (2026-11-07, new session, BeamNG 0.40.5):** the vehicle config came back, the key binding did not. The log only has "local to cloud" lines (`game-state.json`, `settings.json`, `consoleHistory.json`), no "cloud to local". So the mod is needed.
- **Test 6 session A (2026-11-07):** after rebinding, the game reloads ("Loaded 328 bindings" instead of 339), but the export finds **0 files** in `/settings/inputmaps/`. On 2026-11-06 (0.40.4) there was 1 file. Unclear where 0.40.5 stores the key bindings. Session B therefore makes no sense yet.
- **Diagnosis (2026-11-07):** `keyboard.diff` is correctly in the user folder under `/settings/inputmaps/`. All other input maps come from the game folder. The screen resolution is lost per session as well. Next try: test 4b with both categories.
- **Test 8, session A, export (2026-11-07):** BeamNG also uploads the **subfolder** `settings/cloud/settingsCloudSync/files/…` to the Steam Cloud immediately. 8 files were uploaded, including `inputmaps/keyboard.diff`, `game-settings.json` and `settings.json`. Afterwards the game reports "Saved 19 entries to knownFiles.json".
- ✅ **Test 9, session B, import (2026-11-07, definitely a new session):** `keyboard.diff` locally was `false`, the import fetched 8 files. The game applies the resolution (2560×1440, 120 Hz) and the key bindings **immediately, without a restart**. **The mod's approach works on Boosteroid.**

- **File system on Boosteroid (2026-11-09):** Steam only syncs `…\BeamNG\BeamNG.drive.cloud\` (with `steam_autocloud.vdf`); the user folder `…\BeamNG.drive\current\` stays local. Our backup is correctly in the cloud. `mods\db.json` and `mods\repo\` are local only. `settings/cloud/mods-optout.json` is empty (`{}`). **Even a subscribed mod is gone after the session**, it has to be activated again in every session. Details in `docs/RESEARCH.md`.

## Next steps

1. ✔ Mod v0.2 adjusted: only "Controls & key bindings" and "Other settings". BeamNG syncs vehicle configs itself.
2. ✔ New session: the vehicle came back, the key binding did not
3. ✔ Export and import across two sessions successful (test 4b), subfolders are synced
4. ✔ v0.3: auto-import at game start (option stored in `settings/cloud/settingsCloudSync/config.json`), no more restart notice, tested with 0.40.5. Logic: import if `backupId` in the manifest ≠ `backupId` in `settings/settingsCloudSync_state.json` (local)
5. ✔ **Auto-import works on Boosteroid (2026-11-09, published version from the repository):** after activating the mod everything was back, without a click in the app.
6. ✔ Submitted on 2026-11-07 as v0.3 (unique ID `MTQ6X9OL2`, category User Interface Apps), **approved and published (reported 2026-11-09)**. Now: test items 5 and 7 on Boosteroid, upload v0.4 as an update.
7. ✔ **Answered (2026-11-09): the mod does not persist.** In a new session everything is gone, including the mod ("like a new game"). So per session: search the mod in the repository and activate it, then auto-import runs immediately. Original question: mods and their active state (`mods/`, `mods/db.json`) are not in `knownFiles.json`, so they are not synced via Steam Cloud. Test after approval: subscribe to the mod, start a new session. Is it back by itself? If not, auto-import on Boosteroid is pointless and the mod has to be installed per session. Based on `docs/REPOSITORY.md` (tested on 0.40.5)
8. ✔ v0.4 (2026-11-07), suggestion from the forum (gallaxforce now): **profiles**, because PCs with different hardware need different graphics settings. Each profile has its own backup under `settings/cloud/settingsCloudSync/profiles/<name>/`. "Default" uses the old paths, v0.3 backups stay valid. A machine's profile is stored locally only in `settings/settingsCloudSync_state.json`. A fresh machine takes the profile auto-import was enabled with (`autoImportProfile` in `config.json`). Switching profiles does not import automatically. Deleting profiles is not possible yet. **Untested in game**, test plan in `docs/TEST.md`. Included in v0.5, not uploaded separately.
9. v0.5 (2026-11-09): export/import in the **quick access menu** (radial menu, `core_quickAccess`), so the app does not have to stay on screen. The app has a **minimize button**. A dedicated button in the mod's repository entry or in the mod manager is not possible, BeamNG does not support that. **Untested**, test plan in `docs/TEST.md`. Upload as an update (includes v0.4), change note in `docs/REPOSITORY.md`.
10. Also v0.5: **history** with 3 older backups per profile under `…/history/<backupId>/` plus `history/index.json`, each with date and machine name (`COMPUTERNAME`, probably random on Boosteroid). Restoring in the app and radial menu makes the backup the current one again, the previous one moves into the history. An export never overwrites a filled category with 0 files. **Untested.**
11. ✔ Also v0.5: **auto-export** (option `autoExport` in `config.json`). Checks the file contents every 60 s against the state after the last import/export, plus on `onSettingsChanged` and `onExit`. Only runs if the local `backupId` = manifest, so a fresh session overwrites nothing. Only the first automatic export per session adds a history entry. **Untested, only testable on Boosteroid via the repository**, test plan in `docs/TEST.md`.
12. New v0.5 description in `docs/REPOSITORY.md`, editor version without line breaks in `docs/DESCRIPTION_v0.5_editor.txt`. App graphic updated for v0.5 (`grafik/v0.5/png/2_app_en.png`)
13. ✔ **v0.5 uploaded as an update (2026-11-09), waiting for approval.** Mod icon set via "Change Icon".
    **After approval:** (a) replace the description with `docs/DESCRIPTION_v0.5_editor.txt`, (b) swap `2_app_en.png` and adjust the ATTACH number, (c) remove `icon_96.png` from the text, (d) run the test "v0.5 on Boosteroid" from `docs/TEST.md`
14. v0.6 (2026-11-10): **settings in the pause menu** under tab "Mods" > "Settings Cloud Sync" (everything the app can do). Model: the mod "Extra Controller Layouts", which calls `ui_pause_actions.registerModButton` on load via `ui/ui-vue/mods/<name>/index.js` and shows a Vue component. This makes the statement in item 9 obsolete: a dedicated menu entry is possible after all, but in the pause menu, not under Options. Files: `ui/ui-vue/mods/settingsCloudSync/index.js` and `Panel.vue`. **Untested**, test plan in `docs/TEST.md`. Upload only once v0.5 is approved.
15. v0.6 also: the **version** is shown small next to the title in the app and the pause menu. Source: `local version` in the Lua extension (via `getStatus()`); `build.sh` aborts if it differs from `app.json`. **Bump both for every update.**

16. v0.6 also (2026-11-10), from the backlog: shared key bindings (`sharedControls` in `config.json`, backup under `settingsCloudSync/shared/` with its own manifest, history and `sharedBackupId` in the local state), sync status, undo import (`settingsCloudSync_preImport/index.json`), rename/delete profiles (`renamed` map in `config.json`), "Restore mods" (`mods.json`, `core_repository.modSubscribe(tagid)`, button only), removal of stale files, exclusion of credential-like names and files > 512 KB, fixes for the double toast and the random seed. Logic tested with `tests/` (44 checks), **untested in game**, test plan in `docs/TEST.md`. Changes in `CHANGELOG.md`.

## Backlog (2026-11-10)

Translations are not planned.

- [x] Fixes: double toast on restore, random seed, stale files in the cloud, credential-like names and size limit
- [x] Shared key bindings, undo import, sync status, rename/delete profiles
- [x] Research mod list: possible via `core_repository.modSubscribe(tagid)`, details in `docs/RESEARCH.md`; built as button "Restore mods"
- [x] `CHANGELOG.md`
- [ ] Test v0.5 and v0.6 in game and on Boosteroid (`docs/TEST.md`), including whether `CloudSaveData` passes deletions on to Steam and the Steam Cloud quota for BeamNG
- [ ] GitHub releases with tags (from v0.6 on, the earlier versions have no commits of their own)
- [ ] Short video/GIF for the repository page: Boosteroid session, activate the mod, settings are back
