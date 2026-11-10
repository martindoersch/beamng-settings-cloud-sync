# Submission to the BeamNG repository

Sources: https://beamng.com/game/support/policies/modding-guidelines/ · https://docs.beamng.com/modding/mod-support/

Mod page: https://www.beamng.com/resources/settings-cloud-sync.40234/

## Process

1. ✔ Account on beamng.com: `martindoersch`
2. Repository → "Upload a mod" or "Add resource"
3. Fill in:
   - Title: `Settings Cloud Sync`
   - Category: "User Interface Apps"
   - Version: `0.5`
   - Upload zip: `dist/settings_cloud_sync_martindoersch.zip`
   - Description (draft below)
   - At least 2 images via "Upload Images": `grafik/v0.6/png/1_ablauf_en.png`, `grafik/v0.6/png/2_app_en.png`
   - Upload the icon first (`grafik/v0.6/png/icon.png`); the server builds it into the mod itself
   - **Note:** the mod icon is set separately (on the mod page via "Change Icon"), not as an image in the description. Otherwise the game shows a generic cube. ✔ Done on 2026-11-09
4. Wait: moderators check every mod by hand, which can take a few working days. If there are problems, a private message explains what to change.
5. Updates: button "Post resource update", **same zip name**, higher version, short change note

## Rules that apply to us

- Zip name unique, only `A-Z a-z 0-9 - _`, **without version number**, e.g. `settings_cloud_sync_martindoersch.zip` (username martindoersch). Never change it, updates need the same name
- Works via drag and drop or the "Install" button, without extra steps ✔
- No error messages in the console: **must be tested beforehand**
- No readme file in the zip, everything goes into the description ✔
- Do not overwrite game files ✔ (own file names only)
- Must work with the current game version
- Moderators may reject mods of insufficient quality

## Description v0.6 (replace completely, after the v0.6 update is approved)

Editor version (one line per paragraph, with the ATTACH image numbers): `docs/DESCRIPTION_v0.6_editor.txt`. Before pasting: update "Tested on Boosteroid with BeamNG.drive …" after the v0.6 test, and replace image 1351975 (app screenshot) with `grafik/v0.6/png/2_app_en.png` and put its new ATTACH number into the text. If the icon on the mod page is still the v0.5 one, change it via "Change Icon" to `grafik/v0.6/png/icon.png`.

## Description v0.5 (replace completely)

```
Settings Cloud Sync

Take your setup with you. BeamNG already syncs your main game settings via
Steam Cloud, and even your own vehicle configs - but not your key bindings or
graphics settings. This UI app puts them into the game's Steam Cloud folder
(settings/cloud), so you can restore them on another PC or on a cloud gaming
service like Boosteroid.

Playing on Boosteroid or another cloud gaming service?
Every session starts like a fresh install - your settings AND your mods are
gone, including this one (subscribing doesn't help). Set it up once, then
each session takes 20 seconds:
- Once: install the mod, add the app, tick "Auto-import at game start" and
  "Auto-export changes", then click "Export". You can minimize the app or
  remove it from your UI afterwards.
- Every new session: find "Settings Cloud Sync" in the repository and
  activate it. That's it - your key bindings and graphics settings are
  restored automatically, no restart needed. Changes you make are saved
  automatically within a minute.
- Quit the game via the menu, so Steam can upload your settings.
Tested on Boosteroid with BeamNG.drive 0.40.5.

How to use (two PCs)
1. Add the "Settings Cloud Sync" app to your UI (UI Apps > Add app).
2. Tick what you want to sync and click "Export". Quit the game via the menu
   so Steam can upload the cloud folder.
3. On the other machine: start the game, tick the same boxes and click
   "Import". Most settings apply right away.
Everything is also in the pause menu (ESC > Mods > Settings Cloud Sync),
so the app doesn't have to stay on screen. Use the "-" button to minimize it.

Auto-import
Tick "Auto-import at game start" once. A fresh machine uses the profile that
was active when you ticked it. From then on, the mod restores your backup
automatically whenever the cloud backup is newer than the settings on that
machine - ideal for cloud gaming, where every session starts fresh.

Auto-export
Tick "Auto-export changes" once. The mod then saves your settings by itself
within a minute after you change something, and when you quit. For safety it
only starts after this machine has imported or exported once, so a fresh
session can never overwrite your backup with default settings.

Profiles
Playing on different machines with different hardware? Create a profile per
machine (e.g. "Desktop", "Laptop", "Boosteroid") and pick it in the pause
menu or the app. Each
profile has its own backup, so your laptop never gets your desktop's graphics
settings. The profile choice is stored only on that machine.

Backup history
Your 3 previous backups (per profile) are kept, each labelled with date and
PC name. Something went wrong? Pick an older backup under "Older backups"
and click "Restore". It becomes your current backup again,
and the one you replaced moves into the history - nothing gets lost.
Auto-export adds only one history entry per session.
An export never replaces your saved key bindings with "nothing".
Before importing, your current local files are also saved to
settings/settingsCloudSync_preImport.

What can be synced
- Controls & key bindings, keyboard and controller (settings/inputmaps)
- Other settings files in your user folder (graphics, UI layouts etc.)

Console: settingsCloudSync.exportAll() / settingsCloudSync.importAll()
         settingsCloudSync.setProfile('Laptop')
Only text files from your own user folder are copied; nothing leaves your
Steam account.
```

## Change note v0.6 (for "Post resource update", after v0.5 is approved)

```
v0.6
- Settings in the pause menu under Mods > Settings Cloud Sync.
- Share your key bindings across all profiles, graphics stay per profile.
- Sync status shows whether your settings are in the cloud backup.
- Undo import: puts back your local settings from before the last import.
- Restore mods: remembers your active repository mods and subscribes them
  again on a fresh cloud gaming session - one click, needs your BeamNG login.
- Rename and delete profiles.
- The radial menu entries are gone, everything is in the pause menu now.
- Files that look like logins or tokens are never copied.
```

## Change note v0.5 (for "Post resource update", includes v0.4)

```
v0.5
- Auto-export: changes are saved by themselves within a minute and when you
  quit - no more forgotten exports at the end of a cloud gaming session.
- Backup history: your last 3 backups are kept with date and PC name and
  can be restored from the app or the radial menu.
- Profiles: one profile per machine (e.g. Desktop, Laptop, Boosteroid), so
  each keeps its own graphics settings. Existing backups become "Default".
  Thanks to gallaxforce now for the suggestion.
- Export, Import and Restore in the radial menu; the app can be minimized.
- Description: step-by-step guide for Boosteroid and cloud gaming.
```

## Change note v0.4 (not uploaded, included in v0.5)

```
v0.4: Profiles. Create one profile per machine (e.g. Desktop, Laptop,
Boosteroid) so each keeps its own graphics settings and key bindings.
Existing backups become the "Default" profile. Thanks to gallaxforce now
for the suggestion.
```
