-- Settings Cloud Sync
-- Copies selected categories (key bindings, other settings) to settings/cloud/.
-- BeamNG itself uploads this folder including subfolders to the Steam Cloud (engine::Platform::CloudSaveData,
-- tested with 0.40.4 and 0.40.5). Vehicle configs (vehicles/*.pc) are already synced by BeamNG itself.
-- Auto-import (optional): import at game start if the backup in the cloud is newer than the
-- local state, e.g. on a fresh cloud gaming machine.
-- Profiles: one backup per profile, e.g. for PCs with different graphics. Which profile a
-- machine uses is stored locally only; a fresh machine takes the profile auto-import was enabled with.
-- Shared key bindings (optional): the controls go into one backup for all profiles (shared/),
-- only graphics etc. stay per profile. Each backup ("unit") has its own manifest, history and backupId.
-- Console: settingsCloudSync.exportAll() / settingsCloudSync.importAll()
--          optionally with a selection, e.g. settingsCloudSync.exportAll({controls=true})
--          settingsCloudSync.setAutoImport(true)
--          settingsCloudSync.setAutoExport(true)
--          settingsCloudSync.setSharedControls(true)
-- Auto-export (optional): saves changes by itself once this machine is in sync with the cloud
-- (after an import or export). Checks every 60 s, when settings change and on exit.
--          settingsCloudSync.setProfile('Laptop')
--          settingsCloudSync.renameProfile('Laptop', 'Notebook') / settingsCloudSync.deleteProfile('Notebook')
-- Quick access (radial menu): entry "Settings Cloud Sync" with export, import, undo and older backups
-- Pause menu: tab "Mods" > "Settings Cloud Sync" with all settings of the app (ui/ui-vue/mods/settingsCloudSync/)
-- History: before each export the previous backup moves to history/<backupId>/, the last 3 are kept.
--          settingsCloudSync.restoreBackup('<backupId>') restores one of them and makes it the current one
-- Undo: every import saves the local files first, settingsCloudSync.undoImport() puts them back
-- Mod list: each export remembers the active repository mods, settingsCloudSync.restoreMods()
--          subscribes the missing ones again (cloud gaming starts without mods). Never automatic.

local M = {}

local version = '0.6' -- shown in the UI; keep in sync with app.json (build.sh checks this)
local logTag = 'settingsCloudSync'
local cloudRoot = '/settings/cloud/settingsCloudSync/'
local configPath = cloudRoot .. 'config.json' -- lives in the cloud so the option reaches a fresh machine
local sharedRoot = cloudRoot .. 'shared/' -- key bindings shared by all profiles (option sharedControls)
local modListPath = cloudRoot .. 'mods.json' -- active repository mods at the last export
local statePath = '/settings/settingsCloudSync_state.json' -- local only: profile and last active backups
local defaultProfile = 'Default' -- uses the v0.3 paths so existing backups stay valid
local preImportRoot = '/settings/settingsCloudSync_preImport' -- local backup before every import (undo)
local undoIndexPath = preImportRoot .. '/index.json'
local historyKeep = 3 -- number of older backups kept per profile in the cloud
local autoExportInterval = 60 -- seconds between two checks for changes
local maxFileSize = 512 * 1024 -- bigger files are skipped, settings files are a few KB
local maxModSubscribe = 40 -- the repository blocks too many subscriptions per minute
local ownTagid = 'MTQ6X9OL2' -- this mod in the repository, never part of the mod list

-- Text files only: readFile/writeFile are not meant for binary data
local allowedExt = { json = true, diff = true, pc = true, ini = true, cs = true, txt = true }

-- Never copied in any category: possible credentials of other mods and our own files (plain text match on the path)
local excludeAlways = { 'token', 'auth', 'password', 'secret', 'credential', 'cookie', 'session', 'settingscloudsync' }

-- Categories in UI order. exclude: Lua patterns matched against the lowercased path
local categories = {
  { id = 'controls', label = 'Controls & key bindings', dir = '/settings/inputmaps/', pattern = '*' },
  { id = 'otherSettings', label = 'Other settings (graphics, UI layouts etc.)', dir = '/settings/', pattern = '*',
    exclude = { '^/settings/cloud/', '^/settings/inputmaps/' } },
}

local autoImportPending = false
local autoExportTimer = 0
local baseline = nil -- file contents after the last import/export, for auto-export
local archivedThisSession = {} -- per unit: automatic exports add a history entry only once per session
local quickAccessAdded = false
local warnedLarge = {} -- warn about a too big file only once per session

math.randomseed(os.time()) -- LuaJIT otherwise repeats the same numbers in every session

local function now()
  return os.date('%Y-%m-%d %H:%M')
end

local function newBackupId()
  return os.date('%Y%m%d%H%M%S') .. '-' .. math.random(1000, 9999)
end

local function normalize(p)
  return (p or ''):gsub('\\', '/'):lower()
end

local function notify(kind, msg)
  log(kind == 'error' and 'E' or 'I', logTag, msg)
  guihooks.trigger('toastrMsg', { type = kind, title = 'Settings Cloud Sync', msg = msg })
end

-- true if the file really is in the user folder (not in the game folder, not in a mod zip)
local function isUserFile(vpath)
  local real = normalize(FS:getFileRealPath(vpath))
  local user = normalize(FS:getUserPath())
  if real == '' or user == '' then return false end
  if real:sub(1, #user) ~= user then return false end
  return not real:find('/mods/', 1, true)
end

local function matchesCategory(cat, vpath)
  local lower = vpath:lower()
  for _, word in ipairs(excludeAlways) do
    if lower:find(word, 1, true) then return false end
  end
  for _, pat in ipairs(cat.exclude or {}) do
    if lower:find(pat) then return false end
  end
  local ext = lower:match('%.(%w+)$')
  return ext ~= nil and allowedExt[ext] == true and isUserFile(vpath)
end

-- Safety on import: only write back to allowed locations
local function isRestorable(vpath)
  return type(vpath) == 'string'
    and not vpath:find('..', 1, true)
    and vpath:find('^/settings/')
    and not vpath:lower():find('^/settings/cloud/')
end

local function isSelected(selection, id)
  return selection == nil or selection[id] == true
end

local function ensureDir(filePath)
  local dir = filePath:match('^(.*)/[^/]*$')
  if dir and dir ~= '' and not FS:directoryExists(dir) then
    FS:directoryCreate(dir, true)
  end
end

local function copyFile(src, dst)
  local data = readFile(src)
  if not data then return false end
  ensureDir(dst)
  writeFile(dst, data)
  return true
end

local function removeFile(path)
  if FS:fileExists(path) then pcall(function() FS:removeFile(path) end) end
end

-- All files below a folder with their path relative to it; skips anything outside (case may differ)
local function filesBelow(root)
  local list = {}
  for _, path in ipairs(FS:findFiles(root, '*', -1, true, false)) do
    if path:sub(1, #root):lower() == root:lower() then
      table.insert(list, { path = path, rel = path:sub(#root + 1) })
    end
  end
  return list
end

local function readConfig()
  local config = jsonReadFile(configPath)
  return type(config) == 'table' and config or {}
end

local function readState()
  local state = jsonReadFile(statePath)
  return type(state) == 'table' and state or {}
end

-- Profile names become folder names: only letters, digits, spaces, - and _
local function cleanProfileName(name)
  name = tostring(name or ''):gsub('[^%w _%-]', ''):sub(1, 32):match('^%s*(.-)%s*$')
  return name ~= '' and name or nil
end

local function listProfiles(config)
  local profiles = { defaultProfile }
  for _, p in ipairs(type(config.profiles) == 'table' and config.profiles or {}) do
    if type(p) == 'string' and p:lower() ~= defaultProfile:lower() then table.insert(profiles, p) end
  end
  return profiles
end

-- Keep the existing spelling, case does not matter
local function findProfile(config, name)
  for _, p in ipairs(listProfiles(config)) do
    if p:lower() == name:lower() then return p end
  end
end

-- Follows renames done on another machine (config.renamed: old name lowercased → new name)
local function resolveProfile(config, name)
  local renamed = type(config.renamed) == 'table' and config.renamed or {}
  for _ = 1, 10 do
    local nextName = renamed[name:lower()]
    if type(nextName) ~= 'string' then break end
    name = nextName
  end
  return findProfile(config, name)
end

-- Profile of this machine; a fresh machine takes the auto-import profile.
-- Second result: the name this machine used if that profile was deleted meanwhile
local function activeProfile(config)
  config = config or readConfig()
  local stateName = readState().profile
  local name = stateName or config.autoImportProfile or defaultProfile
  local profile = resolveProfile(config, name)
  if profile then return profile end
  return defaultProfile, stateName
end

local function profileRoot(profile)
  if profile == defaultProfile then return cloudRoot end
  return cloudRoot .. 'profiles/' .. profile .. '/'
end

-- A unit is one backup in the cloud with the categories it holds: normally the profile with
-- all categories; with shared key bindings the controls go into a unit of their own
local function getUnits(config)
  config = config or readConfig()
  local profile = activeProfile(config)
  local profileUnit = { key = 'profile', root = profileRoot(profile), cats = {} }
  local sharedUnit = { key = 'shared', root = sharedRoot, cats = {} }
  for _, cat in ipairs(categories) do
    if cat.id == 'controls' and config.sharedControls == true then
      table.insert(sharedUnit.cats, cat)
    else
      table.insert(profileUnit.cats, cat)
    end
  end
  local list = { profileUnit }
  if #sharedUnit.cats > 0 then table.insert(list, sharedUnit) end
  return list
end

-- Field in the local state that holds the last active backupId of a unit
local function stateField(unitKey)
  return unitKey == 'shared' and 'sharedBackupId' or 'backupId'
end

local function readManifest(root)
  local manifest = jsonReadFile(root .. 'manifest.json')
  if type(manifest) ~= 'table' or type(manifest.categories) ~= 'table' then return nil end
  return manifest
end

-- Machine name shown with backups; often random on cloud gaming machines
local function machineName()
  local ok, name = pcall(os.getenv, 'COMPUTERNAME')
  if ok and type(name) == 'string' and name ~= '' then return name end
  return 'unknown PC'
end

-- The IDs end up in paths: only digits, letters and -
local function isValidId(id)
  return type(id) == 'string' and id:match('^[%w%-]+$') ~= nil
end

local function manifestFiles(manifest)
  local list = {}
  for _, entry in pairs(manifest.categories) do
    if type(entry) == 'table' and type(entry.files) == 'table' then
      for _, f in ipairs(entry.files) do table.insert(list, f) end
    end
  end
  return list
end

-- v0.3/v0.4 manifests have no date of their own: take the newest of the categories
local function manifestCreated(manifest)
  if manifest.created then return manifest.created end
  local latest
  for _, entry in pairs(manifest.categories) do
    if type(entry) == 'table' and entry.created and (not latest or entry.created > latest) then latest = entry.created end
  end
  return latest or '?'
end

local function backupLabel(entry, unitKey)
  local label = string.format('%s · %s (%d files)', entry.created or '?', entry.machine or 'unknown PC', entry.count or 0)
  return unitKey == 'shared' and 'Key bindings: ' .. label or label
end

local function historyRoot(root)
  return root .. 'history/'
end

local function readHistory(root)
  local index = jsonReadFile(historyRoot(root) .. 'index.json')
  local list = {}
  for _, entry in ipairs(type(index) == 'table' and type(index.backups) == 'table' and index.backups or {}) do
    if type(entry) == 'table' and isValidId(entry.id) then table.insert(list, entry) end
  end
  return list
end

-- Copy the previous backup into the history, keep only the last historyKeep
local function archiveCurrent(root)
  local manifest = readManifest(root)
  if not manifest or not isValidId(manifest.backupId) then return end
  local files = manifestFiles(manifest)
  local archive = historyRoot(root) .. manifest.backupId .. '/'
  for _, f in ipairs(files) do
    if isRestorable(f) then copyFile(root .. 'files' .. f, archive .. 'files' .. f) end
  end
  jsonWriteFile(archive .. 'manifest.json', manifest, true)
  local list = readHistory(root)
  table.insert(list, 1, { id = manifest.backupId, created = manifestCreated(manifest), machine = manifest.machine, count = #files })
  while #list > historyKeep do
    local oldRoot = historyRoot(root) .. table.remove(list).id .. '/'
    local oldManifest = jsonReadFile(oldRoot .. 'manifest.json')
    if type(oldManifest) == 'table' and type(oldManifest.categories) == 'table' then
      for _, f in ipairs(manifestFiles(oldManifest)) do
        if isRestorable(f) then removeFile(oldRoot .. 'files' .. f) end
      end
    end
    removeFile(oldRoot .. 'manifest.json')
  end
  jsonWriteFile(historyRoot(root) .. 'index.json', { backups = list }, true)
end

-- Removes files of an earlier export that are no longer part of the backup (e.g. a reset keyboard.diff)
local function removeStaleFiles(root, manifest)
  local keep = {}
  for _, f in ipairs(manifestFiles(manifest)) do keep[f:lower()] = true end
  for _, f in ipairs(filesBelow(root .. 'files')) do
    if f.rel:lower():find('^/settings/') and not keep[f.rel:lower()] then removeFile(f.path) end
  end
end

-- Remembers which backup of a unit was last exported or imported on this machine
local function rememberBackup(unitKey, backupId)
  local state = readState()
  state.profile = activeProfile()
  state[stateField(unitKey)] = backupId
  state.updated = now()
  jsonWriteFile(statePath, state, true)
end

-- Files of a category in the user folder: list of paths and path → content. Too big files are skipped
local function collect(cat)
  local files, contents = {}, {}
  for _, f in ipairs(FS:findFiles(cat.dir, cat.pattern, -1, true, false)) do
    if matchesCategory(cat, f) then
      local data = readFile(f)
      if data and #data <= maxFileSize then
        table.insert(files, f)
        contents[f] = data
      elseif data and not warnedLarge[f] then
        warnedLarge[f] = true
        log('W', logTag, string.format('Skipped %s: %d KB is too big for a settings file', f, math.floor(#data / 1024)))
      end
    end
  end
  return files, contents
end

-- Category id → (path → content) of all files an export would include
local function snapshot()
  local snap = {}
  for _, cat in ipairs(categories) do
    local _, contents = collect(cat)
    snap[cat.id] = contents
  end
  return snap
end

local function sameFiles(a, b)
  for k, v in pairs(a) do
    if b[k] ~= v then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function sameSnapshot(a, b)
  for _, cat in ipairs(categories) do
    if not sameFiles(a[cat.id] or {}, b[cat.id] or {}) then return false end
  end
  return true
end

-- true if the local files of the unit's categories equal its backup in the cloud
local function unitMatches(unit, manifest, snap)
  for _, cat in ipairs(unit.cats) do
    local entry = manifest.categories[cat.id]
    local saved = {}
    if type(entry) == 'table' and type(entry.files) == 'table' then
      for _, f in ipairs(entry.files) do
        saved[f] = readFile(unit.root .. 'files' .. f) or ''
      end
    end
    if not sameFiles(snap[cat.id] or {}, saved) then return false end
  end
  return true
end

-- Remembers the active repository mods (repo ID = tagid), except this mod; for "Restore mods"
local function saveModList()
  if not core_modmanager or not core_modmanager.getMods then return end
  local ok, mods = pcall(core_modmanager.getMods)
  if not ok or type(mods) ~= 'table' then return end
  local list = {}
  for name, entry in pairs(mods) do
    local tagid = type(entry) == 'table' and entry.active and type(entry.modData) == 'table' and entry.modData.tagid
    if type(tagid) == 'string' and tagid ~= '' and tagid ~= ownTagid and not name:lower():find('settings_cloud_sync', 1, true) then
      table.insert(list, { id = tagid, name = entry.modData.title or name })
    end
  end
  if #list == 0 then return end -- a fresh session without mods never overwrites the list
  table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  jsonWriteFile(modListPath, { created = now(), machine = machineName(), mods = list }, true)
end

local function readModList()
  local data = jsonReadFile(modListPath)
  local list = {}
  for _, m in ipairs(type(data) == 'table' and type(data.mods) == 'table' and data.mods or {}) do
    if type(m) == 'table' and type(m.id) == 'string' and m.id:match('^[%w]+$') then table.insert(list, m) end
  end
  return list, type(data) == 'table' and data.created or nil
end

-- Repo IDs of all installed mods (active or not)
local function installedModIds()
  local ids = {}
  local ok, mods = pcall(core_modmanager.getMods)
  for _, entry in pairs(ok and type(mods) == 'table' and mods or {}) do
    if type(entry) == 'table' and type(entry.modData) == 'table' and entry.modData.tagid then
      ids[entry.modData.tagid] = entry
    end
  end
  return ids
end

-- Subscribes the remembered mods that are missing and activates installed but inactive ones.
-- Needs the BeamNG login; without it the game queues the subscriptions until online.
local function restoreMods()
  if not core_repository or not core_repository.modSubscribe or not core_modmanager or not core_modmanager.getMods then
    notify('error', 'The mod repository is not available in this game version.')
    return
  end
  local list = readModList()
  if #list == 0 then
    notify('error', 'No mod list saved yet. Export once with your mods active.')
    return
  end
  local installed = installedModIds()
  local subscribed, activated = 0, 0
  for _, m in ipairs(list) do
    local entry = installed[m.id]
    if entry and not entry.active and core_modmanager.activateModId then
      if pcall(core_modmanager.activateModId, entry.modID or m.id) then activated = activated + 1 end
    elseif not entry and subscribed < maxModSubscribe then
      if pcall(core_repository.modSubscribe, m.id) then subscribed = subscribed + 1 end
    end
  end
  if subscribed + activated == 0 then
    notify('success', 'All saved mods are already active.')
  else
    notify('success', string.format('%d mods subscribed, %d activated. Downloads run in the background; you need to be logged in to BeamNG.', subscribed, activated))
  end
end

-- auto = true: no message, only changed backups are written and only the first export of the
-- session goes into the history. quiet = true: no message (restore shows its own)
local function exportAll(selection, auto, quiet)
  local config = readConfig()
  local snap = auto and snapshot() or nil
  local total, skipped, exported = 0, {}, false
  for _, unit in ipairs(getUnits(config)) do
    local current = readManifest(unit.root)
    -- Collect first: a category without files never overwrites a filled backup,
    -- e.g. an export in a fresh cloud gaming session without custom key bindings
    local found = {}
    for _, cat in ipairs(unit.cats) do
      if isSelected(selection, cat.id) then
        local files = collect(cat)
        local saved = current and current.categories[cat.id]
        if #files == 0 and type(saved) == 'table' and type(saved.files) == 'table' and #saved.files > 0 then
          table.insert(skipped, cat.label)
        else
          found[cat.id] = files
        end
      end
    end
    local unchanged = auto and current and unitMatches(unit, current, snap)
    if next(found) ~= nil and not unchanged then
      if not auto or not archivedThisSession[unit.key] then
        archiveCurrent(unit.root)
        archivedThisSession[unit.key] = true
      end
      local manifest = readManifest(unit.root) or { categories = {} }
      for _, cat in ipairs(unit.cats) do
        if found[cat.id] then
          local files = {}
          for _, f in ipairs(found[cat.id]) do
            if copyFile(f, unit.root .. 'files' .. f) then table.insert(files, f) end
          end
          manifest.categories[cat.id] = { created = now(), files = files }
          total = total + #files
        end
      end
      manifest.created = now()
      manifest.machine = machineName()
      manifest.backupId = newBackupId()
      jsonWriteFile(unit.root .. 'manifest.json', manifest, true)
      removeStaleFiles(unit.root, manifest)
      rememberBackup(unit.key, manifest.backupId)
      exported = true
    end
  end
  if not exported then
    if auto then
      log('D', logTag, 'Auto-export: nothing to do')
    else
      notify('error', 'Nothing exported: no settings files found, your backup stays as it is.')
    end
    return
  end
  pcall(saveModList)
  baseline = snapshot()
  local profile = activeProfile(config)
  if auto or quiet then
    log('I', logTag, string.format('Export: %d files backed up (profile "%s")', total, profile))
  else
    notify('success', string.format('%d files backed up to Steam Cloud folder (profile "%s").', total, profile))
    if #skipped > 0 then
      notify('warning', 'Kept the previous backup for: ' .. table.concat(skipped, ', ') .. ' (no files found on this machine).')
    end
  end
end

local function readUndo()
  local index = jsonReadFile(undoIndexPath)
  if type(index) ~= 'table' or type(index.saved) ~= 'table' or type(index.added) ~= 'table' then return nil end
  return index
end

-- Starts a new undo point; the files of the previous one are removed
local function beginUndo()
  local old = readUndo()
  if old then
    for _, f in ipairs(old.saved) do
      if isRestorable(f) then removeFile(preImportRoot .. f) end
    end
    removeFile(undoIndexPath)
  end
  return { created = now(), saved = {}, added = {} }
end

local function finishUndo(undo)
  if #undo.saved + #undo.added > 0 then jsonWriteFile(undoIndexPath, undo, true) end
end

-- Copies the files of the given categories back; local files are first saved for undo
local function importFrom(filesRoot, manifest, cats, selection, undo)
  local count = 0
  for _, cat in ipairs(cats) do
    local entry = manifest.categories[cat.id]
    if isSelected(selection, cat.id) and type(entry) == 'table' and type(entry.files) == 'table' then
      for _, f in ipairs(entry.files) do
        if isRestorable(f) then
          if isUserFile(f) and copyFile(f, preImportRoot .. f) then
            table.insert(undo.saved, f)
          else
            table.insert(undo.added, f) -- did not exist in the user folder: undo removes it again
          end
          if copyFile(filesRoot .. f, f) then count = count + 1 end
        end
      end
    end
  end
  return count
end

-- onlyUnits: set of unit keys to import (auto-import), nil = all
local function importAll(selection, onlyUnits)
  local config = readConfig()
  local todo = {}
  for _, unit in ipairs(getUnits(config)) do
    local manifest = readManifest(unit.root)
    if manifest and (not onlyUnits or onlyUnits[unit.key]) then
      table.insert(todo, { unit = unit, manifest = manifest })
    end
  end
  local profile = activeProfile(config)
  if #todo == 0 then
    notify('error', string.format('No backup found for profile "%s".', profile))
    return
  end
  local undo = beginUndo()
  local count = 0
  for _, t in ipairs(todo) do
    count = count + importFrom(t.unit.root .. 'files', t.manifest, t.unit.cats, selection, undo)
    rememberBackup(t.unit.key, t.manifest.backupId)
  end
  finishUndo(undo)
  baseline = snapshot()
  notify('success', string.format('%d files restored from profile "%s". Most settings apply right away; restart the game if something is missing.', count, profile))
end

-- Puts back the local files from before the last import. The cloud backup stays as it is;
-- auto-export only saves again after the next change.
local function undoImport()
  local undo = readUndo()
  if not undo then
    notify('error', 'There is no import to undo.')
    return
  end
  local count = 0
  for _, f in ipairs(undo.saved) do
    if isRestorable(f) and copyFile(preImportRoot .. f, f) then count = count + 1 end
  end
  for _, f in ipairs(undo.added) do
    if isRestorable(f) and isUserFile(f) then
      removeFile(f)
      count = count + 1
    end
  end
  beginUndo() -- removes the saved files, an undo works only once
  baseline = snapshot()
  notify('success', string.format('%d files are back to the state before the import of %s. Restart the game if something is missing.', count, undo.created or '?'))
end

-- Restore an older backup and make it the current one again (also for auto-import).
-- The previous current backup moves into the history, nothing gets lost.
local function restoreBackup(id)
  if not isValidId(id) then return end
  for _, unit in ipairs(getUnits()) do
    local manifest = jsonReadFile(historyRoot(unit.root) .. id .. '/manifest.json')
    if type(manifest) == 'table' and type(manifest.categories) == 'table' then
      local undo = beginUndo()
      local count = importFrom(historyRoot(unit.root) .. id .. '/files', manifest, unit.cats, nil, undo)
      finishUndo(undo)
      local selection = {}
      for _, cat in ipairs(unit.cats) do
        if manifest.categories[cat.id] then selection[cat.id] = true end
      end
      exportAll(selection, false, true)
      notify('success', string.format('%d files restored from the backup of %s.', count, manifestCreated(manifest)))
      return
    end
  end
  notify('error', 'This backup no longer exists.')
end

-- true if this machine has imported or exported the current backups (protects against
-- a fresh session overwriting the cloud with default settings)
local function machineInSync(config)
  local _, missing = activeProfile(config)
  if missing then return false end
  local state = readState()
  local any = false
  for _, unit in ipairs(getUnits(config)) do
    local manifest = readManifest(unit.root)
    if manifest then
      if state[stateField(unit.key)] ~= manifest.backupId then return false end
      any = true
    end
  end
  return any
end

-- Auto-import only if enabled and a cloud backup is not yet active on this machine
local function autoImportIfNeeded()
  local config = readConfig()
  if not config.autoImport then return end
  local profile, missing = activeProfile(config)
  if missing then
    notify('warning', string.format('Profile "%s" no longer exists, nothing imported. Choose a profile in the app.', missing))
    return
  end
  local state = readState()
  local todo = nil
  for _, unit in ipairs(getUnits(config)) do
    local manifest = readManifest(unit.root)
    if manifest and manifest.backupId and state[stateField(unit.key)] ~= manifest.backupId then
      todo = todo or {}
      todo[unit.key] = true
    end
  end
  if not todo then return end
  log('I', logTag, string.format('Auto-import (profile "%s")', profile))
  importAll(nil, todo)
end

-- The profile active when enabling also applies to fresh machines
local function setAutoImport(enabled)
  local config = readConfig()
  config.autoImport = enabled == true
  if config.autoImport then config.autoImportProfile = activeProfile(config) end
  jsonWriteFile(configPath, config, true)
  -- When enabling, mark the current state as known so no import happens right away
  if config.autoImport then
    local state = readState()
    for _, unit in ipairs(getUnits(config)) do
      local manifest = readManifest(unit.root)
      if manifest and manifest.backupId and not state[stateField(unit.key)] then
        rememberBackup(unit.key, manifest.backupId)
      end
    end
  end
end

-- Saves changes only if this machine has the cloud state (imported or exported).
-- This way a fresh session without an import can never overwrite the backup.
local function autoExportIfChanged()
  local config = readConfig()
  if not config.autoExport or not machineInSync(config) then return end
  local snap = snapshot()
  if not baseline then
    baseline = snap
    return
  end
  if sameSnapshot(snap, baseline) then return end
  exportAll(nil, true)
end

local function setAutoExport(enabled)
  local config = readConfig()
  config.autoExport = enabled == true
  jsonWriteFile(configPath, config, true)
  baseline = config.autoExport and snapshot() or nil
end

-- Copies one category from one backup to another (switching shared key bindings on or off).
-- This machine stays in sync if it was in sync with both backups before.
local function copyCategory(catId, from, to)
  local source = readManifest(from.root)
  local entry = source and source.categories[catId]
  if type(entry) ~= 'table' or type(entry.files) ~= 'table' or #entry.files == 0 then return end
  local state = readState()
  local target = readManifest(to.root)
  local inSync = state[stateField(from.key)] == source.backupId
    and (target == nil or state[stateField(to.key)] == target.backupId)
  archiveCurrent(to.root)
  target = target or { categories = {} }
  local files = {}
  for _, f in ipairs(entry.files) do
    if isRestorable(f) and copyFile(from.root .. 'files' .. f, to.root .. 'files' .. f) then table.insert(files, f) end
  end
  target.categories[catId] = { created = entry.created, files = files }
  target.created = now()
  target.machine = machineName()
  target.backupId = newBackupId()
  jsonWriteFile(to.root .. 'manifest.json', target, true)
  removeStaleFiles(to.root, target)
  if inSync then rememberBackup(to.key, target.backupId) end
end

-- Key bindings in one backup for all profiles, graphics etc. stay per profile.
-- Takes the key bindings along so neither backup starts empty.
local function setSharedControls(enabled)
  enabled = enabled == true
  local config = readConfig()
  if (config.sharedControls == true) == enabled then return end
  local profileUnit = { key = 'profile', root = profileRoot(activeProfile(config)) }
  local sharedUnit = { key = 'shared', root = sharedRoot }
  config.sharedControls = enabled
  jsonWriteFile(configPath, config, true)
  if enabled then
    if readManifest(sharedRoot) then
      notify('success', 'Key bindings are shared again. The shared backup is used, Import to apply it here.')
    else
      copyCategory('controls', profileUnit, sharedUnit)
      notify('success', 'Key bindings are now shared by all profiles.')
    end
  else
    copyCategory('controls', sharedUnit, profileUnit)
    notify('success', 'Each profile has its own key bindings again.')
  end
  baseline = snapshot()
end

-- Switch or create a profile; applies to this machine only. Imports nothing, that is what "Import" does.
local function setProfile(name)
  local clean = cleanProfileName(name)
  if not clean then
    notify('error', 'Profile names may only contain letters, digits, spaces, - and _.')
    return
  end
  local config = readConfig()
  local profile = findProfile(config, clean)
  if not profile then
    profile = clean
    config.profiles = listProfiles(config)
    table.insert(config.profiles, profile)
    jsonWriteFile(configPath, config, true)
  end
  local state = readState()
  if state.profile ~= profile then
    -- Not in sync with the new profile's backup; the shared key bindings stay in sync
    state.profile = profile
    state.backupId = nil
    state.updated = now()
    jsonWriteFile(statePath, state, true)
  end
end

-- Renames a profile for all machines; others follow via config.renamed
local function renameProfile(oldName, newName)
  local config = readConfig()
  local old = findProfile(config, cleanProfileName(oldName) or '')
  local clean = cleanProfileName(newName)
  if not old then notify('error', 'This profile does not exist.') return end
  if old == defaultProfile then notify('error', 'The profile "Default" cannot be renamed.') return end
  if not clean then notify('error', 'Profile names may only contain letters, digits, spaces, - and _.') return end
  local existing = findProfile(config, clean)
  if clean:lower() == defaultProfile:lower() or (existing and existing ~= old) then
    notify('error', string.format('A profile "%s" already exists.', clean))
    return
  end
  local oldRoot, newRoot = profileRoot(old), profileRoot(clean)
  -- A change of case only keeps the folder (Windows paths ignore case)
  if oldRoot:lower() ~= newRoot:lower() then
    local files = filesBelow(oldRoot)
    for _, f in ipairs(files) do
      if not copyFile(f.path, newRoot .. f.rel) then
        notify('error', 'Renaming failed, the profile stays as it is.')
        return
      end
    end
    for _, f in ipairs(files) do removeFile(f.path) end
  end
  for i, p in ipairs(config.profiles or {}) do
    if p == old then config.profiles[i] = clean end
  end
  if type(config.autoImportProfile) == 'string' and config.autoImportProfile:lower() == old:lower() then
    config.autoImportProfile = clean
  end
  config.renamed = type(config.renamed) == 'table' and config.renamed or {}
  config.renamed[old:lower()] = clean
  config.renamed[clean:lower()] = nil -- renaming back must not loop
  jsonWriteFile(configPath, config, true)
  local state = readState()
  if type(state.profile) == 'string' and state.profile:lower() == old:lower() then
    state.profile = clean
    jsonWriteFile(statePath, state, true)
  end
  notify('success', string.format('Profile "%s" renamed to "%s".', old, clean))
end

-- Deletes a profile with its backups for all machines. This machine switches to Default if needed.
local function deleteProfile(name)
  local config = readConfig()
  local profile = findProfile(config, cleanProfileName(name) or '')
  if not profile then notify('error', 'This profile does not exist.') return end
  if profile == defaultProfile then notify('error', 'The profile "Default" cannot be deleted.') return end
  for _, f in ipairs(filesBelow(profileRoot(profile))) do removeFile(f.path) end
  local profiles = {}
  for _, p in ipairs(config.profiles or {}) do
    if p ~= profile then table.insert(profiles, p) end
  end
  config.profiles = profiles
  if type(config.autoImportProfile) == 'string' and config.autoImportProfile:lower() == profile:lower() then
    config.autoImportProfile = defaultProfile
  end
  for old, new in pairs(type(config.renamed) == 'table' and config.renamed or {}) do
    if type(new) == 'string' and new:lower() == profile:lower() then config.renamed[old] = nil end
  end
  jsonWriteFile(configPath, config, true)
  local _, missing = activeProfile(config)
  if missing then setProfile(defaultProfile) end
  notify('success', string.format('Profile "%s" deleted.', profile))
end

-- 'none': no backup yet, 'synced': local files equal the cloud backup, 'changed': they differ
local function syncState(config)
  local snap = snapshot()
  local any = false
  for _, unit in ipairs(getUnits(config)) do
    local manifest = readManifest(unit.root)
    if manifest then
      any = true
      if not unitMatches(unit, manifest, snap) then return 'changed' end
    end
  end
  return any and 'synced' or 'none'
end

-- All older backups of this machine's units, newest first per unit
local function allHistory(config)
  local list = {}
  for _, unit in ipairs(getUnits(config)) do
    for _, entry in ipairs(readHistory(unit.root)) do
      table.insert(list, { id = entry.id, label = backupLabel(entry, unit.key) })
    end
  end
  return list
end

-- For the UI: categories with the state of the last backup, options, sync state, undo, mods
local function getStatus()
  local config = readConfig()
  local profile, missing = activeProfile(config)
  local units = getUnits(config)
  local entries, current, sharedCurrent = {}, nil, nil
  for _, unit in ipairs(units) do
    local manifest = readManifest(unit.root)
    if manifest then
      local label = backupLabel({ created = manifestCreated(manifest), machine = manifest.machine,
        count = #manifestFiles(manifest) }, unit.key)
      if unit.key == 'shared' then sharedCurrent = label else current = label end
      for _, cat in ipairs(unit.cats) do entries[cat.id] = manifest.categories[cat.id] end
    end
  end
  local undo = readUndo()
  local mods, modsCreated = readModList()
  local result = {
    version = version,
    current = current,
    sharedCurrent = sharedCurrent,
    history = allHistory(config),
    autoImport = config.autoImport == true,
    autoExport = config.autoExport == true,
    sharedControls = config.sharedControls == true,
    autoImportProfile = config.autoImportProfile or defaultProfile,
    profile = profile,
    missingProfile = missing,
    profiles = listProfiles(config),
    sync = syncState(config),
    linked = machineInSync(config),
    undo = undo and string.format('%s (%d files)', undo.created or '?', #undo.saved + #undo.added) or nil,
    modCount = #mods,
    modsCreated = modsCreated,
    categories = {},
  }
  for _, cat in ipairs(categories) do
    local entry = entries[cat.id]
    table.insert(result.categories, {
      id = cat.id,
      label = cat.label,
      shared = cat.id == 'controls' and config.sharedControls == true,
      backupDate = type(entry) == 'table' and entry.created or nil,
      backupCount = type(entry) == 'table' and type(entry.files) == 'table' and #entry.files or 0,
    })
  end
  return result
end

-- Export/import in the quick access (radial) menu, so the UI app does not have to stay on screen.
-- Uses the profile and all categories of this machine. Untested: core_quickAccess API in 0.40.x
local function addQuickAccessEntries()
  if quickAccessAdded then return end
  if not core_quickAccess or not core_quickAccess.addEntry then
    log('D', logTag, 'core_quickAccess not available yet')
    return
  end
  quickAccessAdded = true
  local ok, err = pcall(function()
    core_quickAccess.addEntry({ level = '/', generator = function(entries)
      table.insert(entries, { title = 'Settings Cloud Sync', icon = 'cloud_upload', ['goto'] = '/settingsCloudSync/' })
    end })
    core_quickAccess.addEntry({ level = '/settingsCloudSync/', generator = function(entries)
      table.insert(entries, { title = 'Export settings', icon = 'cloud_upload',
        onSelect = function() exportAll() return { 'hide' } end })
      table.insert(entries, { title = 'Import settings', icon = 'cloud_download',
        onSelect = function() importAll() return { 'hide' } end })
      if readUndo() then
        table.insert(entries, { title = 'Undo last import', icon = 'undo',
          onSelect = function() undoImport() return { 'hide' } end })
      end
      table.insert(entries, { title = 'Restore older backup', icon = 'history', ['goto'] = '/settingsCloudSync/restore/' })
    end })
    core_quickAccess.addEntry({ level = '/settingsCloudSync/restore/', generator = function(entries)
      for _, entry in ipairs(allHistory()) do
        table.insert(entries, { title = entry.label, icon = 'history',
          onSelect = function() restoreBackup(entry.id) return { 'hide' } end })
      end
    end })
  end)
  if not ok then log('E', logTag, 'Quick access entries failed: ' .. tostring(err)) end
end

local function onExtensionLoaded()
  autoImportPending = true
end

-- Import only in the first frame, when the UI is ready and can show the message
local function onUpdate(dtReal)
  if autoImportPending then
    autoImportPending = false
    addQuickAccessEntries()
    autoImportIfNeeded()
    if not baseline and readConfig().autoExport then baseline = snapshot() end
    return
  end
  autoExportTimer = autoExportTimer + (tonumber(dtReal) or 0)
  if autoExportTimer < autoExportInterval then return end
  autoExportTimer = 0
  autoExportIfChanged()
end

-- Check soon after settings change (the file may only be written afterwards)
local function onSettingsChanged()
  autoExportTimer = math.max(autoExportTimer, autoExportInterval - 5)
end

local function onClientStartMission()
  addQuickAccessEntries()
end

-- Save the last changes on exit
local function onExit()
  local ok, err = pcall(autoExportIfChanged)
  if not ok then log('E', logTag, 'Auto-export on exit failed: ' .. tostring(err)) end
end

M.exportAll = exportAll
M.importAll = importAll
M.undoImport = undoImport
M.restoreBackup = restoreBackup
M.restoreMods = restoreMods
M.setAutoImport = setAutoImport
M.setAutoExport = setAutoExport
M.setSharedControls = setSharedControls
M.setProfile = setProfile
M.renameProfile = renameProfile
M.deleteProfile = deleteProfile
M.getStatus = getStatus
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.onSettingsChanged = onSettingsChanged
M.onClientStartMission = onClientStartMission
M.onExit = onExit

return M
