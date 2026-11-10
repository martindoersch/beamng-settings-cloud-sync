-- Settings Cloud Sync
-- Copies selected categories (key bindings, other settings) to settings/cloud/.
-- BeamNG itself uploads this folder including subfolders to the Steam Cloud (engine::Platform::CloudSaveData,
-- tested with 0.40.4 and 0.40.5). Vehicle configs (vehicles/*.pc) are already synced by BeamNG itself.
-- Auto-import (optional): import at game start if the backup in the cloud is newer than the
-- local state, e.g. on a fresh cloud gaming machine.
-- Profiles: one backup per profile, e.g. for PCs with different graphics. Which profile a
-- machine uses is stored locally only; a fresh machine takes the profile auto-import was enabled with.
-- Console: settingsCloudSync.exportAll() / settingsCloudSync.importAll()
--          optionally with a selection, e.g. settingsCloudSync.exportAll({controls=true})
--          settingsCloudSync.setAutoImport(true)
--          settingsCloudSync.setAutoExport(true)
-- Auto-export (optional): saves changes by itself once this machine is in sync with the cloud
-- (after an import or export). Checks every 60 s, when settings change and on exit.
--          settingsCloudSync.setProfile('Laptop')
-- Quick access (radial menu): entry "Settings Cloud Sync" with export, import and older backups
-- Pause menu: tab "Mods" > "Settings Cloud Sync" with all settings of the app (ui/ui-vue/mods/settingsCloudSync/)
-- History: before each export the previous backup moves to history/<backupId>/, the last 3 are kept.
--          settingsCloudSync.restoreBackup('<backupId>') restores one of them and makes it the current one

local M = {}

local version = '0.6' -- shown in the UI; keep in sync with app.json (build.sh checks this)
local logTag = 'settingsCloudSync'
local cloudRoot = '/settings/cloud/settingsCloudSync/'
local configPath = cloudRoot .. 'config.json' -- lives in the cloud so the option reaches a fresh machine
local statePath = '/settings/settingsCloudSync_state.json' -- local only: profile and last active backup
local defaultProfile = 'Default' -- uses the v0.3 paths so existing backups stay valid
local preImportRoot = '/settings/settingsCloudSync_preImport' -- local backup before every import
local historyKeep = 3 -- number of older backups kept per profile in the cloud
local autoExportInterval = 60 -- seconds between two checks for changes

-- Text files only: readFile/writeFile are not meant for binary data
local allowedExt = { json = true, diff = true, pc = true, ini = true, cs = true, txt = true }

-- Categories in UI order. exclude: Lua patterns matched against the lowercased path
local categories = {
  { id = 'controls', label = 'Controls & key bindings', dir = '/settings/inputmaps/', pattern = '*' },
  { id = 'otherSettings', label = 'Other settings (graphics, UI layouts etc.)', dir = '/settings/', pattern = '*',
    exclude = { '^/settings/cloud/', '^/settings/inputmaps/', '^/settings/settingscloudsync' } },
}

local autoImportPending = false
local autoExportTimer = 0
local baseline = nil -- file contents after the last import/export, for auto-export
local archivedThisSession = false -- automatic exports add a history entry only once per session
local quickAccessAdded = false

local function now()
  return os.date('%Y-%m-%d %H:%M')
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

-- Profile of this machine; a fresh machine takes the auto-import profile
local function activeProfile()
  local config = readConfig()
  local name = readState().profile or config.autoImportProfile or defaultProfile
  return findProfile(config, name) or defaultProfile
end

local function profileRoot(profile)
  if profile == defaultProfile then return cloudRoot end
  return cloudRoot .. 'profiles/' .. profile .. '/'
end

local function readManifest(profile)
  local manifest = jsonReadFile(profileRoot(profile) .. 'manifest.json')
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

local function backupLabel(entry)
  return string.format('%s · %s (%d files)', entry.created or '?', entry.machine or 'unknown PC', entry.count or 0)
end

local function historyRoot(profile)
  return profileRoot(profile) .. 'history/'
end

local function readHistory(profile)
  local index = jsonReadFile(historyRoot(profile) .. 'index.json')
  local list = {}
  for _, entry in ipairs(type(index) == 'table' and type(index.backups) == 'table' and index.backups or {}) do
    if type(entry) == 'table' and isValidId(entry.id) then table.insert(list, entry) end
  end
  return list
end

local function removeFile(path)
  if FS:fileExists(path) then pcall(function() FS:removeFile(path) end) end
end

-- Copy the previous backup into the history, keep only the last historyKeep
local function archiveCurrent(profile)
  local manifest = readManifest(profile)
  if not manifest or not isValidId(manifest.backupId) then return end
  local files = manifestFiles(manifest)
  local root = historyRoot(profile) .. manifest.backupId .. '/'
  for _, f in ipairs(files) do
    if isRestorable(f) then copyFile(profileRoot(profile) .. 'files' .. f, root .. 'files' .. f) end
  end
  jsonWriteFile(root .. 'manifest.json', manifest, true)
  local list = readHistory(profile)
  table.insert(list, 1, { id = manifest.backupId, created = manifestCreated(manifest), machine = manifest.machine, count = #files })
  while #list > historyKeep do
    local oldRoot = historyRoot(profile) .. table.remove(list).id .. '/'
    local oldManifest = jsonReadFile(oldRoot .. 'manifest.json')
    if type(oldManifest) == 'table' and type(oldManifest.categories) == 'table' then
      for _, f in ipairs(manifestFiles(oldManifest)) do
        if isRestorable(f) then removeFile(oldRoot .. 'files' .. f) end
      end
    end
    removeFile(oldRoot .. 'manifest.json')
  end
  jsonWriteFile(historyRoot(profile) .. 'index.json', { backups = list }, true)
end

-- Remembers which backup was last exported or imported on this machine
local function rememberBackup(profile, backupId)
  jsonWriteFile(statePath, { profile = profile, backupId = backupId, updated = now() }, true)
end

-- Path → content of all files an export would include
local function snapshot()
  local snap = {}
  for _, cat in ipairs(categories) do
    for _, f in ipairs(FS:findFiles(cat.dir, cat.pattern, -1, true, false)) do
      if matchesCategory(cat, f) then snap[f] = readFile(f) or '' end
    end
  end
  return snap
end

local function sameSnapshot(a, b)
  for k, v in pairs(a) do
    if b[k] ~= v then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- auto = true: no message, and only the first export of the session goes into the history
local function exportAll(selection, auto)
  local profile = activeProfile()
  local filesRoot = profileRoot(profile) .. 'files'
  local current = readManifest(profile)
  -- Collect first: a category without files never overwrites a filled backup,
  -- e.g. an export in a fresh cloud gaming session without custom key bindings
  local found, skipped = {}, {}
  for _, cat in ipairs(categories) do
    if isSelected(selection, cat.id) then
      local files = {}
      for _, f in ipairs(FS:findFiles(cat.dir, cat.pattern, -1, true, false)) do
        if matchesCategory(cat, f) then table.insert(files, f) end
      end
      local saved = current and current.categories[cat.id]
      if #files == 0 and type(saved) == 'table' and type(saved.files) == 'table' and #saved.files > 0 then
        table.insert(skipped, cat.label)
      else
        found[cat.id] = files
      end
    end
  end
  if next(found) == nil then
    if auto then
      log('W', logTag, 'Auto-export skipped: no settings files found')
    else
      notify('error', 'Nothing exported: no settings files found, your backup stays as it is.')
    end
    return
  end
  if not auto or not archivedThisSession then
    archiveCurrent(profile)
    archivedThisSession = true
  end
  local manifest = readManifest(profile) or { categories = {} }
  local total = 0
  for _, cat in ipairs(categories) do
    if found[cat.id] then
      local files = {}
      for _, f in ipairs(found[cat.id]) do
        if copyFile(f, filesRoot .. f) then table.insert(files, f) end
      end
      manifest.categories[cat.id] = { created = now(), files = files }
      total = total + #files
    end
  end
  manifest.created = now()
  manifest.machine = machineName()
  manifest.backupId = os.date('%Y%m%d%H%M%S') .. '-' .. math.random(1000, 9999)
  jsonWriteFile(profileRoot(profile) .. 'manifest.json', manifest, true)
  rememberBackup(profile, manifest.backupId)
  baseline = snapshot()
  if auto then
    log('I', logTag, string.format('Auto-export: %d files backed up (profile "%s")', total, profile))
  else
    notify('success', string.format('%d files backed up to Steam Cloud folder (profile "%s").', total, profile))
  end
  if #skipped > 0 and not auto then
    notify('warning', 'Kept the previous backup for: ' .. table.concat(skipped, ', ') .. ' (no files found on this machine).')
  end
end

-- Copies the files of a manifest back; existing files are first saved locally to preImportRoot
local function importFrom(filesRoot, manifest, selection)
  local count = 0
  for _, cat in ipairs(categories) do
    local entry = manifest.categories[cat.id]
    if isSelected(selection, cat.id) and type(entry) == 'table' and type(entry.files) == 'table' then
      for _, f in ipairs(entry.files) do
        if isRestorable(f) then
          if FS:fileExists(f) then copyFile(f, preImportRoot .. f) end
          if copyFile(filesRoot .. f, f) then count = count + 1 end
        end
      end
    end
  end
  return count
end

local function importAll(selection)
  local profile = activeProfile()
  local manifest = readManifest(profile)
  if not manifest then
    notify('error', string.format('No backup found for profile "%s".', profile))
    return
  end
  local count = importFrom(profileRoot(profile) .. 'files', manifest, selection)
  rememberBackup(profile, manifest.backupId)
  baseline = snapshot()
  notify('success', string.format('%d files restored from profile "%s". Most settings apply right away; restart the game if something is missing.', count, profile))
end

-- Restore an older backup and make it the current one again (also for auto-import).
-- The previous current backup moves into the history, nothing gets lost.
local function restoreBackup(id)
  local profile = activeProfile()
  local manifest = isValidId(id) and jsonReadFile(historyRoot(profile) .. id .. '/manifest.json')
  if type(manifest) ~= 'table' or type(manifest.categories) ~= 'table' then
    notify('error', 'This backup no longer exists.')
    return
  end
  local count = importFrom(historyRoot(profile) .. id .. '/files', manifest, nil)
  local selection = {}
  for catId in pairs(manifest.categories) do selection[catId] = true end
  exportAll(selection)
  notify('success', string.format('%d files restored from the backup of %s.', count, manifestCreated(manifest)))
end

-- Auto-import only if enabled and the cloud backup is not yet active on this machine
local function autoImportIfNeeded()
  if not readConfig().autoImport then return end
  local profile = activeProfile()
  local manifest = readManifest(profile)
  if not manifest or not manifest.backupId then return end
  if readState().backupId == manifest.backupId then return end
  log('I', logTag, string.format('Auto-import of backup %s (profile "%s")', tostring(manifest.backupId), profile))
  importAll()
end

-- The profile active when enabling also applies to fresh machines
local function setAutoImport(enabled)
  local config = readConfig()
  local profile = activeProfile()
  config.autoImport = enabled == true
  if config.autoImport then config.autoImportProfile = profile end
  jsonWriteFile(configPath, config, true)
  -- When enabling, mark the current state as known so no import happens right away
  local manifest = readManifest(profile)
  if config.autoImport and manifest and manifest.backupId and not readState().backupId then
    rememberBackup(profile, manifest.backupId)
  end
end

-- Saves changes only if this machine has the cloud state (imported or exported).
-- This way a fresh session without an import can never overwrite the backup.
local function autoExportIfChanged()
  if not readConfig().autoExport then return end
  local manifest = readManifest(activeProfile())
  if not manifest or not manifest.backupId or readState().backupId ~= manifest.backupId then return end
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
    jsonWriteFile(statePath, { profile = profile, updated = now() }, true)
  end
end

-- For the UI app: categories with the state of the last backup and the auto-import option
local function getStatus()
  local config = readConfig()
  local profile = activeProfile()
  local manifest = readManifest(profile)
  local current = manifest and {
    created = manifestCreated(manifest), machine = manifest.machine, count = #manifestFiles(manifest) }
  local history = {}
  for _, entry in ipairs(readHistory(profile)) do
    table.insert(history, { id = entry.id, label = backupLabel(entry) })
  end
  local result = {
    version = version,
    current = current and backupLabel(current) or nil,
    history = history,
    autoImport = config.autoImport == true,
    autoExport = config.autoExport == true,
    autoImportProfile = config.autoImportProfile or defaultProfile,
    profile = profile,
    profiles = listProfiles(config),
    categories = {},
  }
  for _, cat in ipairs(categories) do
    local entry = manifest and manifest.categories[cat.id]
    table.insert(result.categories, {
      id = cat.id,
      label = cat.label,
      backupDate = entry and entry.created or nil,
      backupCount = entry and entry.files and #entry.files or 0,
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
      table.insert(entries, { title = 'Restore older backup', icon = 'history', ['goto'] = '/settingsCloudSync/restore/' })
    end })
    core_quickAccess.addEntry({ level = '/settingsCloudSync/restore/', generator = function(entries)
      for _, entry in ipairs(readHistory(activeProfile())) do
        table.insert(entries, { title = backupLabel(entry), icon = 'history',
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
M.restoreBackup = restoreBackup
M.setAutoImport = setAutoImport
M.setAutoExport = setAutoExport
M.setProfile = setProfile
M.getStatus = getStatus
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.onSettingsChanged = onSettingsChanged
M.onClientStartMission = onClientStartMission
M.onExit = onExit

return M
