angular.module('beamng.apps')
.directive('settingsCloudSync', [function () {
  return {
    template:
      '<div style="padding:8px; background:rgba(0,0,0,0.7); color:white; font-family:sans-serif; font-size:13px; overflow:auto; max-height:100%; box-sizing:border-box;">' +
        '<div style="display:flex; align-items:center; font-weight:bold;" ng-style="{\'margin-bottom\': collapsed ? \'0\' : \'6px\'}">' +
          '<span style="flex:1;">Settings Cloud Sync <span ng-show="version" style="font-weight:normal; font-size:10px; opacity:0.6;">v{{version}}</span></span>' +
          '<button ng-click="toggleCollapsed()" title="{{collapsed ? \'Expand\' : \'Minimize\'}}" style="min-width:24px;">{{collapsed ? \'+\' : \'–\'}}</button>' +
        '</div>' +
        '<div ng-show="!collapsed">' +
        '<div style="margin-bottom:6px;">Profile ' +
          '<button ng-click="stepProfile(-1)" ng-disabled="profiles.length < 2">‹</button> <b>{{profile}}</b> <button ng-click="stepProfile(1)" ng-disabled="profiles.length < 2">›</button> ' +
          '<input type="text" ng-model="newProfile" placeholder="name" maxlength="32" style="width:80px;"> ' +
          '<button ng-click="addProfile()" ng-disabled="!newProfile" title="Create a new profile with this name">Add</button> ' +
          '<button ng-click="renameProfile()" ng-disabled="!newProfile || profile === \'Default\'" title="Rename the selected profile">Rename</button> ' +
          '<button ng-click="deleteProfile()" ng-disabled="profile === \'Default\'" title="Delete the selected profile and its backups">{{confirmDelete ? \'Really?\' : \'Delete\'}}</button>' +
          '<div style="opacity:0.6;">e.g. one per PC; only this machine switches</div>' +
          '<div ng-show="missingProfile" style="color:#ffcc80;">Profile \'{{missingProfile}}\' was deleted, this machine uses Default.</div>' +
        '</div>' +
        '<label ng-repeat="c in categories" style="display:block; margin-bottom:3px;">' +
          '<input type="checkbox" ng-model="selection[c.id]" ng-change="saveSelection()"> {{c.label}}' +
          '<div style="opacity:0.6; margin-left:20px;">{{c.shared ? "shared by all profiles, " : ""}}{{c.backupDate ? (c.backupCount + (c.backupCount === 1 ? " file, " : " files, ") + c.backupDate) : "no backup yet"}}</div>' +
        '</label>' +
        '<div style="margin-top:6px;">' +
          '<button ng-click="run(\'exportAll\')">Export</button> ' +
          '<button ng-click="run(\'importAll\')">Import</button> ' +
          '<button ng-show="undo" ng-click="call(\'undoImport()\')" title="Puts back the local files from before the import of {{undo}}">Undo import</button>' +
        '</div>' +
        '<div style="margin-top:6px;" ng-style="{color: syncColor()}">{{syncText()}}</div>' +
        '<div style="margin-top:2px; opacity:0.6;">Current: {{current || "no backup yet"}}</div>' +
        '<div style="opacity:0.6;" ng-show="sharedCurrent">{{sharedCurrent}}</div>' +
        '<div style="margin-top:4px;" ng-show="history.length">Older ' +
          '<button ng-click="stepRestore(-1)" ng-disabled="history.length < 2">‹</button> {{restoreLabel()}} <button ng-click="stepRestore(1)" ng-disabled="history.length < 2">›</button> ' +
          '<button ng-click="restoreBackup()" ng-disabled="!restore.id">Restore</button>' +
        '</div>' +
        '<label style="display:block; margin-top:6px;">' +
          '<input type="checkbox" ng-model="autoImport" ng-change="setOption(\'setAutoImport\', autoImport)"> Auto-import at game start' +
          '<div style="opacity:0.6; margin-left:20px;">when the cloud backup is newer, e.g. on cloud gaming. ' +
          'Fresh machines use profile \'{{autoImportProfile}}\'</div>' +
        '</label>' +
        '<label style="display:block; margin-top:4px;">' +
          '<input type="checkbox" ng-model="autoExport" ng-change="setOption(\'setAutoExport\', autoExport)"> Auto-export changes' +
          '<div style="opacity:0.6; margin-left:20px;">saves within a minute, once this machine has imported or exported</div>' +
        '</label>' +
        '<label style="display:block; margin-top:4px;">' +
          '<input type="checkbox" ng-model="sharedControls" ng-change="setOption(\'setSharedControls\', sharedControls)"> Share key bindings across profiles' +
          '<div style="opacity:0.6; margin-left:20px;">graphics etc. stay per profile</div>' +
        '</label>' +
        '<div style="margin-top:6px;" ng-show="modCount">' +
          '<button ng-click="call(\'restoreMods()\')">Restore mods ({{modCount}})</button>' +
          '<div style="opacity:0.6;">subscribes the repository mods that were active at the export of {{modsCreated}}; needs the BeamNG login</div>' +
        '</div>' +
        '<div style="opacity:0.6; margin-top:6px;">Tip: also in the pause menu (ESC) under Mods.</div>' +
        '</div>' +
      '</div>',
    replace: true,
    restrict: 'EA',
    link: function (scope) {
      var storageKey = 'settingsCloudSync.selection'
      var collapsedKey = 'settingsCloudSync.collapsed'
      scope.collapsed = localStorage.getItem(collapsedKey) === 'true'
      scope.categories = []
      scope.autoImport = false
      scope.autoExport = false
      scope.sharedControls = false
      scope.profiles = []
      scope.profile = ''
      scope.newProfile = ''
      scope.history = []
      scope.restore = { id: '' }
      scope.confirmDelete = false
      scope.selection = JSON.parse(localStorage.getItem(storageKey) || 'null') || {}

      // Selection as a Lua table, e.g. {controls=true,otherSettings=false}
      function selectionToLua () {
        return '{' + Object.keys(scope.selection).map(function (k) {
          return k + '=' + (scope.selection[k] ? 'true' : 'false')
        }).join(',') + '}'
      }

      // Allowed characters only, so the name stays a valid Lua string
      function cleanName (name) {
        return String(name || '').replace(/[^A-Za-z0-9 _-]/g, '')
      }

      scope.refresh = function () {
        bngApi.engineLua('settingsCloudSync.getStatus()', function (data) {
          scope.$evalAsync(function () {
            data = data || {}
            scope.categories = data.categories || []
            scope.autoImport = data.autoImport === true
            scope.autoExport = data.autoExport === true
            scope.sharedControls = data.sharedControls === true
            scope.autoImportProfile = data.autoImportProfile
            scope.profiles = data.profiles || []
            scope.profile = data.profile
            scope.missingProfile = data.missingProfile
            scope.version = data.version
            scope.current = data.current
            scope.sharedCurrent = data.sharedCurrent
            scope.sync = data.sync
            scope.linked = data.linked === true
            scope.undo = data.undo
            scope.modCount = data.modCount || 0
            scope.modsCreated = data.modsCreated
            scope.history = Array.isArray(data.history) ? data.history : []
            // Preselect the newest older backup, so the shown entry is also the one Restore uses
            if (!scope.history.some(function (b) { return b.id === scope.restore.id })) {
              scope.restore.id = scope.history.length ? scope.history[0].id : ''
            }
            scope.categories.forEach(function (c) {
              if (scope.selection[c.id] === undefined) scope.selection[c.id] = true
            })
          })
        })
      }

      scope.syncText = function () {
        if (scope.sync === 'synced') return '✔ In sync with the cloud backup'
        if (scope.sync === 'changed') {
          if (scope.autoExport && scope.linked) return 'Local changes, auto-export saves them within a minute'
          if (scope.autoExport) return 'Local changes; auto-export starts after the first import or export here'
          return 'Local changes are not in the cloud backup yet'
        }
        return 'No backup yet'
      }

      scope.syncColor = function () {
        return scope.sync === 'synced' ? '#a5d6a7' : scope.sync === 'changed' ? '#ffcc80' : 'white'
      }

      scope.toggleCollapsed = function () {
        scope.collapsed = !scope.collapsed
        localStorage.setItem(collapsedKey, scope.collapsed ? 'true' : 'false')
      }

      scope.saveSelection = function () {
        localStorage.setItem(storageKey, JSON.stringify(scope.selection))
      }

      scope.call = function (code, delay) {
        bngApi.engineLua('settingsCloudSync.' + code)
        setTimeout(scope.refresh, delay || 500)
      }

      // The options live in the cloud (not in localStorage) so they reach a fresh machine
      scope.setOption = function (fn, enabled) {
        scope.call(fn + '(' + (enabled ? 'true' : 'false') + ')')
      }

      scope.setProfile = function (name) {
        scope.confirmDelete = false
        scope.call('setProfile("' + cleanName(name) + '")', 300)
      }

      // Arrows instead of a <select>: its dropdown does not open in the game UI
      function step (list, current, dir) {
        var i = list.indexOf(current)
        return list[(i + dir + list.length) % list.length]
      }

      scope.stepProfile = function (dir) {
        if (scope.profiles.length > 1) scope.setProfile(step(scope.profiles, scope.profile, dir))
      }

      scope.stepRestore = function (dir) {
        var ids = scope.history.map(function (b) { return b.id })
        if (ids.length > 1) scope.restore.id = step(ids, scope.restore.id, dir)
      }

      scope.restoreLabel = function () {
        var b = scope.history.filter(function (h) { return h.id === scope.restore.id })[0]
        return b ? b.label : ''
      }

      scope.addProfile = function () {
        scope.setProfile(scope.newProfile)
        scope.newProfile = ''
      }

      scope.renameProfile = function () {
        scope.call('renameProfile("' + cleanName(scope.profile) + '", "' + cleanName(scope.newProfile) + '")')
        scope.newProfile = ''
      }

      // Second click confirms; dialogs do not work reliably in the game UI
      scope.deleteProfile = function () {
        if (!scope.confirmDelete) {
          scope.confirmDelete = true
          setTimeout(function () { scope.$evalAsync(function () { scope.confirmDelete = false }) }, 4000)
          return
        }
        scope.confirmDelete = false
        scope.call('deleteProfile("' + cleanName(scope.profile) + '")')
      }

      // Restores the backup and makes it the current one; the previous one moves into the history
      scope.restoreBackup = function () {
        var id = String(scope.restore.id || '').replace(/[^A-Za-z0-9-]/g, '')
        if (!id) return
        scope.call('restoreBackup("' + id + '")', 800)
      }

      scope.run = function (fn) {
        scope.call(fn + '(' + selectionToLua() + ')')
      }

      // Keeps the sync state current, e.g. after a change in the options or an auto-export
      var timer = setInterval(function () { if (!scope.collapsed) scope.refresh() }, 15000)
      scope.$on('$destroy', function () { clearInterval(timer) })

      scope.refresh()
    }
  }
}])
