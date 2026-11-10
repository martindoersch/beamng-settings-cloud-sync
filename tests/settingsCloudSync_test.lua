-- Mock of the BeamNG environment with an in-memory user folder and game folder
local extPath = arg[1]
local files = {}      -- user folder: lowercased vpath -> { path, data }
local gameFiles = {}  -- game folder (read only)
local toasts = {}
local function key(p) return p:lower() end

local function serialize(v, ind)
  ind = ind or ''
  if type(v) == 'table' then
    local parts = {}
    for k, x in pairs(v) do
      local kk = type(k) == 'number' and '[' .. k .. ']' or '[' .. string.format('%q', k) .. ']'
      table.insert(parts, kk .. '=' .. serialize(x))
    end
    return '{' .. table.concat(parts, ',') .. '}'
  elseif type(v) == 'string' then return string.format('%q', v)
  else return tostring(v) end
end

function readFile(p)
  local f = files[key(p)] or gameFiles[key(p)]
  return f and f.data or nil
end
function writeFile(p, d) files[key(p)] = { path = p, data = d } return true end
function jsonWriteFile(p, t) writeFile(p, 'return ' .. serialize(t)) return true end
function jsonReadFile(p)
  local d = readFile(p)
  if not d then return nil end
  return load(d)()
end
function log(level, tag, msg) if level == 'E' or level == 'W' then print('  [log ' .. level .. '] ' .. msg) end end
guihooks = { trigger = function(_, t) table.insert(toasts, t) print('  [toast ' .. t.type .. '] ' .. t.msg) end }

FS = {}
function FS:getUserPath() return 'C:/Users/x/AppData/Local/BeamNG/BeamNG.drive/current/' end
function FS:getFileRealPath(p)
  if files[key(p)] then return 'C:\\Users\\x\\AppData\\Local\\BeamNG\\BeamNG.drive\\current' .. p:gsub('/', '\\') end
  if gameFiles[key(p)] then return 'C:/Games/BeamNG' .. p end
  return ''
end
function FS:fileExists(p) return files[key(p)] ~= nil or gameFiles[key(p)] ~= nil end
function FS:directoryExists(p) return true end
function FS:directoryCreate() return true end
function FS:removeFile(p) files[key(p)] = nil end
function FS:findFiles(dir, pattern, depth)
  local out, seen = {}, {}
  local d = dir:lower()
  if d:sub(-1) ~= '/' then d = d .. '/' end
  for _, src in ipairs({ files, gameFiles }) do
    for k, f in pairs(src) do
      if k:sub(1, #d) == d and not seen[k] then seen[k] = true table.insert(out, f.path) end
    end
  end
  table.sort(out)
  return out
end

local subscribed, activated = {}, {}
core_modmanager = {
  getMods = function() return {
    ['some_map'] = { active = true, modID = 'MAPID', modData = { tagid = 'MAPID', title = 'Some Map' } },
    ['old_car'] = { active = false, modID = 'CARID', modData = { tagid = 'CARID', title = 'Old Car' } },
    ['settings_cloud_sync_martindoersch'] = { active = true, modData = { tagid = 'MTQ6X9OL2' } },
    ['local_mod'] = { active = true },
  } end,
  activateModId = function(id) table.insert(activated, id) end,
}
core_repository = { modSubscribe = function(id) table.insert(subscribed, id) end }

-- Test helpers
local fails = 0
local function check(cond, msg)
  print((cond and 'PASS ' or 'FAIL ') .. msg)
  if not cond then fails = fails + 1 end
end
local function count(prefix)
  local n = 0
  for k in pairs(files) do if k:sub(1, #prefix) == prefix:lower() then n = n + 1 end end
  return n
end
local function newSession() -- like a fresh cloud gaming machine: only settings/cloud survives
  for k in pairs(files) do
    if k:sub(1, #'/settings/cloud/') ~= '/settings/cloud/' then files[k] = nil end
  end
end
local function loadExt()
  local m = dofile(extPath)
  m.onExtensionLoaded()
  return m
end

-- Setup
writeFile('/settings/inputmaps/keyboard.diff', 'keys v1')
writeFile('/settings/game-settings.json', 'gfx v1')
writeFile('/settings/ui_apps/layout.json', 'layout v1')
writeFile('/settings/beammp_auth_token.json', 'SECRET')
writeFile('/settings/huge.json', string.rep('x', 600 * 1024))
gameFiles['/settings/inputmaps/xbox.json'] = { path = '/settings/inputmaps/xbox.json', data = 'game default' }

local m = loadExt()
m.onUpdate(0)
local root = '/settings/cloud/settingsCloudSync/'

print('== export')
m.exportAll()
local man = jsonReadFile(root .. 'manifest.json')
check(man and #man.categories.controls.files == 1, 'controls: 1 file (game folder input map skipped)')
check(man and #man.categories.otherSettings.files == 2, 'other settings: 2 files (token and huge file skipped)')
check(readFile(root .. 'files/settings/beammp_auth_token.json') == nil, 'token not in the cloud')
check(m.getStatus().sync == 'synced', 'status synced after export')
local mods = jsonReadFile(root .. 'mods.json')
check(mods and #mods.mods == 1 and mods.mods[1].id == 'MAPID', 'mod list: only the active repo mod, not this mod')

print('== status changed')
writeFile('/settings/game-settings.json', 'gfx v2')
check(m.getStatus().sync == 'changed', 'status changed after local change')

print('== stale files and empty protection')
files['/settings/ui_apps/layout.json'] = nil
files['/settings/inputmaps/keyboard.diff'] = nil
m.exportAll()
man = jsonReadFile(root .. 'manifest.json')
check(readFile(root .. 'files/settings/ui_apps/layout.json') == nil, 'removed file deleted from cloud backup')
check(#man.categories.controls.files == 1, 'empty controls kept the previous backup')
check(readFile(root .. 'files/settings/inputmaps/keyboard.diff') == 'keys v1', 'key bindings still in the cloud')
check(#jsonReadFile(root .. 'history/index.json').backups == 1, 'history has 1 entry')

print('== double toast on restore')
local histId = jsonReadFile(root .. 'history/index.json').backups[1].id
for i = #toasts, 1, -1 do toasts[i] = nil end
m.restoreBackup(histId)
check(#toasts == 1 and toasts[1].msg:find('restored from the backup'), 'restore shows exactly one message')
check(readFile('/settings/ui_apps/layout.json') == 'layout v1', 'restore brought the layout back')
check(m.getStatus().undo ~= nil, 'restore can be undone')

print('== history limit')
for i = 1, 5 do writeFile('/settings/game-settings.json', 'gfx loop ' .. i) m.exportAll() end
check(#jsonReadFile(root .. 'history/index.json').backups == 3, 'history keeps 3')
check(count(root .. 'history/') == 3 * 4 + 1, 'old history files removed (3 backups x 4 files + index)')

print('== auto-import in a new session + undo')
m.setAutoImport(true)
writeFile('/settings/inputmaps/keyboard.diff', 'keys v1')
m.exportAll()
newSession()
writeFile('/settings/game-settings.json', 'fresh default')
m = loadExt()
m.onUpdate(0)
check(readFile('/settings/inputmaps/keyboard.diff') == 'keys v1', 'auto-import restored key bindings')
check(readFile('/settings/game-settings.json') == 'gfx loop 5', 'auto-import restored graphics')
check(m.getStatus().sync == 'synced' and m.getStatus().linked, 'synced and linked after auto-import')
m.undoImport()
check(readFile('/settings/game-settings.json') == 'fresh default', 'undo put back the previous file')
check(readFile('/settings/inputmaps/keyboard.diff') == nil, 'undo removed the file that did not exist before')
check(m.getStatus().undo == nil, 'undo works only once')
m.importAll()

print('== auto-export')
m.setAutoExport(true)
local before = jsonReadFile(root .. 'manifest.json').backupId
m.onUpdate(61)
check(jsonReadFile(root .. 'manifest.json').backupId == before, 'no auto-export without change')
writeFile('/settings/game-settings.json', 'gfx auto')
m.onUpdate(61)
check(jsonReadFile(root .. 'manifest.json').backupId ~= before, 'auto-export after change')
check(readFile(root .. 'files/settings/game-settings.json') == 'gfx auto', 'auto-export wrote the file')
print('-- fresh session without auto-import must not overwrite the backup')
m.setAutoImport(false)
newSession()
writeFile('/settings/game-settings.json', 'defaults!')
m = loadExt()
m.onUpdate(0)
m.onUpdate(61)
m.onExit()
check(readFile(root .. 'files/settings/game-settings.json') == 'gfx auto', 'backup not overwritten by a fresh session')
m.importAll()
m.setAutoImport(true)

print('== shared key bindings')
m.setSharedControls(true)
local shared = jsonReadFile(root .. 'shared/manifest.json')
check(shared and #shared.categories.controls.files == 1, 'shared backup created with key bindings')
check(m.getStatus().linked, 'still linked after enabling shared')
m.setProfile('Laptop')
writeFile('/settings/inputmaps/keyboard.diff', 'keys laptop')
writeFile('/settings/game-settings.json', 'gfx laptop')
m.exportAll()
local lap = jsonReadFile(root .. 'profiles/Laptop/manifest.json')
check(lap and lap.categories.controls == nil and #lap.categories.otherSettings.files == 2, 'Laptop profile holds only other settings')
check(readFile(root .. 'shared/files/settings/inputmaps/keyboard.diff') == 'keys laptop', 'key bindings went into the shared backup')
m.setProfile('Default')
m.importAll()
check(readFile('/settings/inputmaps/keyboard.diff') == 'keys laptop', 'Default gets the shared key bindings')
check(readFile('/settings/game-settings.json') == 'gfx auto', 'Default keeps its own graphics')

print('== rename and delete')
m.setProfile('Laptop')
m.renameProfile('Laptop', 'Notebook')
check(readFile(root .. 'profiles/Notebook/manifest.json') ~= nil and count(root .. 'profiles/laptop/') == 0, 'files moved to Notebook')
check(m.getStatus().profile == 'Notebook', 'this machine follows the rename')
-- another machine still has "Laptop" in its local state
local st = jsonReadFile('/settings/settingsCloudSync_state.json')
st.profile = 'Laptop' jsonWriteFile('/settings/settingsCloudSync_state.json', st)
check(m.getStatus().profile == 'Notebook', 'old name resolves via the rename map')
m.deleteProfile('Notebook')
check(count(root .. 'profiles/notebook/') == 0, 'profile files deleted')
check(m.getStatus().profile == 'Default', 'machine switched to Default')
local p = m.getStatus().profiles
check(#p == 1, 'only Default left')
-- a machine whose profile was deleted elsewhere: no auto-import of Default
jsonWriteFile('/settings/settingsCloudSync_state.json', { profile = 'Gone' })
for i = #toasts, 1, -1 do toasts[i] = nil end
m = loadExt() m.onUpdate(0)
check(#toasts == 1 and toasts[1].type == 'warning', 'deleted profile: warning instead of import')
m.setProfile('Default')

print('== disable shared key bindings')
m.setSharedControls(false)
check(readFile(root .. 'files/settings/inputmaps/keyboard.diff') == 'keys laptop', 'key bindings copied back into the profile')

print('== restore mods')
m.restoreMods()
check(#subscribed == 0 and #activated == 0, 'active mods: nothing to do')
local realGetMods = core_modmanager.getMods
core_modmanager.getMods = function() local t = realGetMods() t.some_map.active = false return t end
m.restoreMods()
check(#activated == 1 and activated[1] == 'MAPID', 'installed but inactive mod gets activated')
core_modmanager.getMods = function() local t = realGetMods() t.some_map = nil return t end
m.restoreMods()
check(#subscribed == 1 and subscribed[1] == 'MAPID', 'missing mod gets subscribed')
-- fresh session without mods must not overwrite the mod list
m.exportAll()
check(#jsonReadFile(root .. 'mods.json').mods == 1, 'mod list kept when no repo mod is active')

print('== invalid input')
m.setProfile('../x')
check(count(root .. 'profiles/..') == 0, 'path traversal sanitized')
m.restoreBackup('../../evil')
m.renameProfile('Default', 'X')

print(fails == 0 and '\nALL TESTS PASSED' or ('\n' .. fails .. ' FAILED'))
