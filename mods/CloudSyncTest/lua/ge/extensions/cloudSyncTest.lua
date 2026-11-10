-- Cloud Sync Test
-- Checks: (1) does the mod load, (2) does the user folder survive between sessions,
-- (3) does Steam sync the folder settings/cloud/.
-- To do so it increments two markers: one in settings/cloud/ and one outside of it.

local M = {}

local logTag = 'cloudSyncTest'
local cloudDir = '/settings/cloud/'
local cloudMarker = cloudDir .. 'cloudSyncTest.json'
local localMarker = '/settings/cloudSyncTest_local.json'

local result

local function bump(path)
  local d = jsonReadFile(path) or { n = 0, history = {} }
  d.n = (d.n or 0) + 1
  d.history = d.history or {}
  table.insert(d.history, os.date('%Y-%m-%d %H:%M:%S'))
  jsonWriteFile(path, d, true)
  return d.n
end

local function runTest()
  local existed = FS:directoryExists(cloudDir)
  if not existed then FS:directoryCreate(cloudDir, true) end
  local files = {}
  for _, f in ipairs(FS:findFiles(cloudDir, '*', -1, true, false)) do table.insert(files, f) end
  result = {
    userPath = FS:getUserPath(),
    cloudDirExisted = existed,
    cloudFiles = files,
    cloudCount = bump(cloudMarker),
    localCount = bump(localMarker),
  }
  jsonWriteFile('/settings/cloudSyncTest_report.json', result, true)
end

local function show()
  if not result then runTest() end
  local msg = string.format('CLOUD=%d  LOCAL=%d  settings/cloud vorher da: %s',
    result.cloudCount, result.localCount, tostring(result.cloudDirExisted))
  log('I', logTag, msg)
  log('I', logTag, 'Userfolder: ' .. tostring(result.userPath))
  for _, f in ipairs(result.cloudFiles) do log('I', logTag, '  ' .. f) end
  guihooks.trigger('toastrMsg', { type = 'info', title = 'Cloud Sync Test', msg = msg })
end

M.onExtensionLoaded = runTest
M.onClientStartMission = show -- Show the toast only once a map is loaded (UI ready)
M.show = show

return M
