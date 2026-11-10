# Cloud sync test (Boosteroid)

Goal: find out whether (a) the user folder survives between Boosteroid sessions and (b) Steam syncs the folder `settings/cloud/`.

## Option A: console (no installation, recommended)

1. Start BeamNG, load a map
2. Open the console: key `~`, on a German keyboard usually `^` or `Ctrl + ~`. **GE - Lua** must be selected at the top.
3. Paste this line and press Enter:

```
local c='/settings/cloud/'; local had=FS:directoryExists(c); if not had then FS:directoryCreate(c,true) end; local function b(p) local d=jsonReadFile(p) or {n=0}; d.n=d.n+1; d.last=os.date(); jsonWriteFile(p,d,true); return d.n end; print('CLOUD='..b(c..'cloudSyncTest.json')..'  LOCAL='..b('/settings/cloudSyncTest_local.json')..'  cloud folder existed before: '..tostring(had)..'  user folder: '..tostring(FS:getUserPath())); for _,f in ipairs(FS:findFiles(c,'*',-1,true,false)) do print('  '..f) end
```

4. **Quit the game properly via the menu**, because Steam only uploads on exit
5. New Boosteroid session, repeat steps 1–3

## Option B: test mod

Put `dist/cloudSyncTest.zip` into the `mods/` folder. After loading a map, a message with the counters appears. In the console you can show it again with `cloudSyncTest.show()`. The report is in `settings/cloudSyncTest_report.json`.

## Evaluation (second session)

| Result | Meaning |
|---|---|
| `LOCAL=2` | The user folder survives. Settings should persist by themselves, the mod is unnecessary. |
| `LOCAL=1`, `CLOUD=2` | Steam Cloud syncs `settings/cloud/`. The Settings Cloud Sync mod works. |
| `LOCAL=1`, `CLOUD=1` | Neither, Steam Cloud is not an option |
| Error message in the console | Take a photo of or copy the error message and send it to Claude |

---

# Test 2: dry run for mod v0.2

Shows per category which files the mod would back up. Nothing is copied. This checks `FS:getFileRealPath` and `FS:findFiles` with a pattern before the mod is submitted.

```
local u=FS:getUserPath():gsub('\\','/'):lower() local function ok(f) local r=(FS:getFileRealPath(f) or ''):gsub('\\','/'):lower() return r~='' and r:sub(1,#u)==u and not r:find('/mods/',1,true) end for _,c in ipairs({{'/settings/inputmaps/','*'},{'/vehicles/','*.pc'},{'/settings/','*'}}) do local n=0 for _,f in ipairs(FS:findFiles(c[1],c[2],-1,true,false)) do if ok(f) then n=n+1 print('  '..f) end end print('>> '..c[1]..' '..c[2]..': '..n..' files') end
```

Expected: the `>>` lines show at least 1 file for `inputmaps` if you have rebound keys, and your own configs for `/vehicles/`. If every line shows 0 although files exist, the user folder comparison is wrong. Then please send a screenshot.

---

# Test 3: what does BeamNG already sync by itself?

Result of test 2: BeamNG uploads saved vehicle configs to the Steam Cloud by itself. The list of synced files is in `knownFiles.json` in the user folder.

1. Show in the console what BeamNG syncs:
```
print(readFile('/knownFiles.json'))
```
2. Rebind any key under Options → Controls
3. Look in the console for a line `Copying from local to cloud: 'settings\inputmaps\keyboard.diff'`. Then run line 1 again.
4. In a new Boosteroid session, look for `Copying from cloud to local` in the console right after the start

---

# Test 4: export and import key bindings via console (like v0.2)

Result of test 5 (2026-11-07, new session, BeamNG 0.40.5): the vehicle config came back, the key binding did not. Since the zip cannot be installed on Boosteroid, these lines replicate the mod's export and import for the category `controls`.

**Session A**
1. Rebind a key under Options → Controls
2. Export:
```
local u=FS:getUserPath():gsub('\\','/'):lower() local n=0 for _,f in ipairs(FS:findFiles('/settings/inputmaps/','*',-1,true,false)) do local r=(FS:getFileRealPath(f) or ''):gsub('\\','/'):lower() if r:sub(1,#u)==u and not r:find('/mods/',1,true) then local d=readFile(f) if d then local t='/settings/cloud/settingsCloudSync/files'..f FS:directoryCreate(t:match('^(.*)/'),true) writeFile(t,d) n=n+1 print('  '..t) end end end print('>> Export: '..n..' files')
```
3. Console filter `CloudSave`: does "Copying from local to cloud: settings\cloud\settingsCloudSync\files\…" appear? This tells us whether BeamNG also syncs **subfolders** of `settings/cloud/`.
4. Quit the game via the menu

**Session B (new Boosteroid session)**
1. Import:
```
local n=0 for _,t in ipairs(FS:findFiles('/settings/cloud/settingsCloudSync/files/settings/inputmaps/','*',-1,true,false)) do local d=readFile(t) if d then local f=t:gsub('^/settings/cloud/settingsCloudSync/files','') FS:directoryCreate(f:match('^(.*)/'),true) writeFile(f,d) n=n+1 print('  '..f) end end print('>> Import: '..n..' files')
```
2. Restart the game and check whether the key is rebound again

| Result | Meaning |
|---|---|
| Import > 0, key is back | The mod works, submit it |
| `Import: 0` | Subfolders are not synced. The mod has to write flat into `settings/cloud/` |

## Diagnosis: where are the key bindings stored? (after `Export: 0`)

Run right after rebinding, in the **same** session:
```
print('USER: '..tostring(FS:getUserPath())) for _,d in ipairs({'/settings/inputmaps/','/settings/'}) do for _,f in ipairs(FS:findFiles(d,'*.diff',-1,true,false)) do print('  '..f..' -> '..tostring(FS:getFileRealPath(f))) end end for _,f in ipairs(FS:findFiles('/settings/inputmaps/','*',-1,true,false)) do print('  IM '..f..' -> '..tostring(FS:getFileRealPath(f))) end print('>> done')
```

**Diagnosis result (2026-11-07, 0.40.5):** the binding is stored as expected under `/settings/inputmaps/keyboard.diff`, real path `C:\Users\user\AppData\Local\BeamNG\BeamNG.drive\current\settings\inputmaps\keyboard.diff`. All other files in `/settings/inputmaps/` come from the game folder. On Boosteroid the screen resolution is lost in every session as well.

## Test 4b: export and import of both categories (keys + other settings)

Export (session A, after rebinding and setting the resolution):
```
local u=FS:getUserPath():gsub('\\','/'):lower() local n=0 for _,f in ipairs(FS:findFiles('/settings/','*',-1,true,false)) do local l=f:lower() local r=(FS:getFileRealPath(f) or ''):gsub('\\','/'):lower() local e=l:match('%.(%w+)$') if r:sub(1,#u)==u and not r:find('/mods/',1,true) and not l:find('^/settings/cloud/') and not l:find('^/settings/settingscloudsync') and ({json=1,diff=1,ini=1,cs=1,txt=1})[e] then local d=readFile(f) if d then local t='/settings/cloud/settingsCloudSync/files'..f FS:directoryCreate(t:match('^(.*)/'),true) writeFile(t,d) n=n+1 print('  '..t) end end end print('>> Export: '..n..' files')
```

Import (session B, then restart the game):
```
local p='/settings/cloud/settingsCloudSync/files' local n=0 for _,t in ipairs(FS:findFiles(p..'/settings/','*',-1,true,false)) do local d=readFile(t) if d then local f=t:sub(#p+1) FS:directoryCreate(f:match('^(.*)/'),true) writeFile(f,d) n=n+1 print('  '..f) end end print('>> Import: '..n..' files')
```

**Tip for a definitely new Boosteroid session:** quit BeamNG, start and quit another game via Boosteroid, then start BeamNG again. Check it with `print(FS:fileExists('/settings/inputmaps/keyboard.diff'))`: `false` means a new session.

## Test v0.4: profiles

Console or UI app; after each step take a quick look at the console (no red errors):

1. Status without changes: `dump(settingsCloudSync.getStatus())`. Expected: `profile = "Default"`, the old v0.3 backup is shown
2. Create a profile: `settingsCloudSync.setProfile('Boosteroid')`, then change the resolution and run `settingsCloudSync.exportAll()`. In the log: files under `settings\cloud\settingsCloudSync\profiles\Boosteroid\…` are copied to the cloud
3. Back to `Default`, `importAll()`. Expected: the old resolution comes back
4. Select `Boosteroid` again, enable auto-import. `config.json` contains `autoImportProfile = "Boosteroid"`
5. New session (see tip above): auto-import fetches the profile **Boosteroid**, the message names the profile
6. Invalid names (`setProfile('../x')`) are sanitized or rejected, nothing ends up outside `settings/cloud/settingsCloudSync/`

## Test v0.5: quick access menu and minimize

1. Console after loading: does the log say `core_quickAccess not available` or `Quick access entries failed`? Then the API works differently in 0.40.x, note the error message
2. Open the radial menu: is there an entry "Settings Cloud Sync"? Below it "Export settings" and "Import settings". Is the icon shown (`cloud_upload`/`cloud_download`)?
3. Export via the radial menu: message "… files backed up", upload to the cloud in the log
4. Import via the radial menu: message "… files restored"
5. UI app: the "–" button collapses it to the title bar, "+" expands it again. The state persists after a restart
6. When collapsed: can the app still be moved, does it cover anything?

## Test v0.5: backup history

1. Export four times, changing something in between (e.g. resolution). Expected: the app shows "Current: date · machine name (n files)" and 3 entries under "Older", the oldest one is gone. If the machine name says "unknown PC", `os.getenv` does not work in BeamNG
2. In the user folder: `settings/cloud/settingsCloudSync/history/` contains exactly 3 folders and `index.json`, old folders are empty or gone
3. Pick the oldest backup in the app → Restore. Expected: its resolution is active again, it is now "Current", the previous current one is listed under "Older"
4. The same via the radial menu: Settings Cloud Sync → Restore older backup → entry
5. Empty protection: rename `keyboard.diff` in the user folder, export. Expected: yellow message "Kept the previous backup for: Controls…", the key bindings in the backup are kept
6. Old backup from v0.3/v0.4 (without machine name): shows "unknown PC", date taken from the categories, no error
7. Console: no red errors, including for `FS:removeFile`

## Test v0.5 on Boosteroid (after the update is approved)

Only testable via the repository. After each step check the console (^) for red errors, filter `settingsCloudSync`.

1. **Start:** activate the mod. Auto-import fetches the v0.3 backup (message "… files restored"). No red lines
2. **App:** "–" at the top right collapses, "+" expands. "Current: 2026-11-09 19:49 · unknown PC (… files)" is shown
3. **Enable auto-export**, then change a setting (e.g. resolution or a controller key). Within 1 minute the log shows: `Auto-export: n files backed up`. "Current" shows the new time and the machine name or "unknown PC"
4. Change something else, wait 1 minute: `Auto-export` again, but **no** additional entry under "Older" (only one per session)
5. **Radial menu:** is there "Settings Cloud Sync" with Export, Import and Restore older backup? With icons?
6. **Restore:** pick the 19:49 backup under "Older" → Restore. It becomes "Current" again, the old resolution is back
7. Quit via the menu. **New session:** activate the mod → auto-import fetches the last saved state. Auto-export is still ticked (stored in `config.json` in the cloud)
8. Protection cross-check: in the new session, change something before activating the mod. After activating, the import must win, no auto-export of the default values

## Test v0.6: settings in the pause menu

1. Install the zip from `dist/`, start the game, load a vehicle
2. Press ESC, open the tab "Mods" in the pause menu: is the entry "Settings Cloud Sync" visible?
3. Open the entry: are profile, categories with status, export/import, history, auto-import and auto-export visible?
4. Trigger an export, does "Current" update? Tick auto-export, close and reopen the menu, is the box still ticked?
5. UI app next to it: does it show the same values (selection, options)?
6. Version: the app title (also when collapsed) and the pause menu heading show a small "v0.6"
7. If the entry is missing: filter the console (`~`) for `settingsCloudSync` and `ui_pause_actions` and take a screenshot

## Test v0.6: new functions from the backlog

Logic is covered by `tests/` (mocked file system); in game it is about the real API and the UI. Console filter `settingsCloudSync`, no red lines.

1. **Sync status:** after an export the app shows a green "In sync with the cloud backup". Change the resolution: within 15 s an orange "Local changes …"
2. **Undo import:** change a key, Import → the old key is back. "Undo import" appears, click it → the changed key is back, the button disappears. Do the key bindings apply right away or only after a restart?
3. **Radial menu:** Settings Cloud Sync → "Undo last import" only appears after an import
4. **Shared key bindings:** tick the option. Folder `settings/cloud/settingsCloudSync/shared/` with `manifest.json` appears. Switch to a second profile, change a key and export → the key ends up in `shared/`, the profile only has other settings. Back to Default, Import → the new key is there, the graphics of Default stay
5. **Rename:** select a profile, type a new name, Rename → the folder under `profiles/` has the new name. **Delete:** first click shows "Really?", second deletes; the machine switches to Default
6. **Stale files:** reset all key bindings (so `keyboard.diff` disappears) but keep another input map, export → `keyboard.diff` is gone from `…/files/settings/inputmaps/`
7. **Restore mods:** with some repository mods active, export. Check `settings/cloud/settingsCloudSync/mods.json` (repo IDs, without this mod). New Boosteroid session: activate this mod, the app shows "Restore mods (n)", click → the mods download and are active. Not logged in: what happens? (the game should queue them)
8. **Steam Cloud deletions:** after step 6, does the log show a deletion for the cloud (`deletedFiles.json`)? Is `keyboard.diff` gone in `BeamNG.drive.cloud` too?
9. **Size limit:** the log shows `Skipped … too big` only for files over 512 KB, normally never

## Results v0.6 (2026-11-10, local PC, BeamNG 0.40.5)

- ✅ Pause menu: entry under Mods, all options visible, version "v0.6" shown
- ✅ Sync status green/orange, undo import works (probably applied right away, not 100 % sure)
- ✅ Delete profile: "Really?", then switches to Default
- ✅ Auto-import/auto-export across two sessions
- ❌ One red line: `CEF.MainGEUI#local://local/ui/ui-vue/dist/runtime.js:833 TypeError: Cannot read properties of undefined (reading 'value')`. Probably the "Older backups" select in the pause menu: `restoreId` was empty, so BngSelect showed the first entry, but Restore stayed disabled. **Fixed:** newest older backup is preselected, select config is null-safe
- ❌ Pause menu: no typing into the name field (the game/menu navigation takes the keys). **Fix attempt:** `setCEFTyping(true)` while the field has focus, key events stopped
- ❌ UI app: the profile dropdown does not open. **Fixed:** ‹ › arrows for profile and older backups
- ❌ Radial menu: entries without labels, wrong icons (traffic light) and empty slots in its own category. **Removed**, the pause menu covers everything
- Open: restore mods (item 7), Steam Cloud deletions (item 8)

## Retest v0.6 after the fixes

1. Console: no red `runtime.js` line when opening ESC > Mods > Settings Cloud Sync
2. Pause menu: type a name, Add / Rename work. While typing, no game actions fire (e.g. camera, radial menu)
3. Pause menu: "Older backups" shows the newest entry, Restore is clickable right away
4. UI app: ‹ › switches the profile, ‹ › picks the older backup, Restore restores the shown one
5. Radial menu: no "Settings Cloud Sync" category anymore
