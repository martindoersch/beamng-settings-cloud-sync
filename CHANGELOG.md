# Changelog

## v0.6 (in development, upload after v0.5 is approved)

- Settings panel in the pause menu under "Mods" > "Settings Cloud Sync"
- Version shown next to the title in the app and the pause menu
- Shared key bindings across all profiles (option), graphics etc. stay per profile
- Sync status: "in sync with the cloud backup" or "local changes"
- Undo import: puts back the local files from before the last import or restore (app, pause menu, radial menu)
- Rename and delete profiles; other machines follow a rename, a deleted profile no longer triggers an auto-import
- Restore mods: each export remembers the active repository mods, a button subscribes the missing ones again (needs the BeamNG login, never automatic)
- Files that are no longer part of a backup are removed from the cloud folder
- Never copied: files whose path contains `token`, `auth`, `password`, `secret`, `credential`, `cookie` or `session`, and files over 512 KB
- Auto-export only writes backups whose content actually changed
- Fix: restoring an older backup showed two messages
- Fix: backup IDs used the same random numbers in every session

## v0.5 (2026-11-09, uploaded, awaiting approval)

- Auto-export: changes are saved within a minute and on exit, once the machine is in sync with the cloud
- Backup history: the last 3 backups per profile, with date and PC name, restorable
- Export, Import and Restore in the radial menu; the app can be minimized
- Includes v0.4: profiles per machine, existing backups become "Default"

## v0.4 (2026-11-07, not uploaded, included in v0.5)

- Profiles, one backup per profile (suggestion by gallaxforce now)

## v0.3 (2026-11-07, published 2026-11-09)

- Auto-import at game start when the cloud backup is newer
- First version in the BeamNG repository

## v0.2 (2026-11-06, not published)

- Only key bindings and other settings; BeamNG syncs vehicle configs itself
