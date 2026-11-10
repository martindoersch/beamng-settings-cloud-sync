angular.module('beamng.apps')
.directive('settingsCloudSync', [function () {
  return {
    template:
      '<div style="padding:8px; background:rgba(0,0,0,0.7); color:white; font-family:sans-serif; font-size:13px; overflow:auto; max-height:100%; box-sizing:border-box;">' +
        '<div style="display:flex; align-items:center; font-weight:bold;" ng-style="{\'margin-bottom\': collapsed ? \'0\' : \'6px\'}">' +
          '<span style="flex:1;">Settings Cloud Sync <span ng-show="version" style="font-weight:normal; font-size:10px; opacity:0.6;">v{{version}}</span></span>' +
          '<button ng-click="toggleCollapsed()" title="{{collapsed ? \'Expand\' : \'Minimize\'}}" style="min-width:24px;">{{collapsed ? \'+\' : \'\u2013\'}}</button>' +
        '</div>' +
        '<div ng-show="!collapsed">' +
        '<div style="margin-bottom:6px;">Profile ' +
          '<select ng-model="profile" ng-options="p for p in profiles" ng-change="setProfile(profile)"></select> ' +
          '<input type="text" ng-model="newProfile" placeholder="new profile" maxlength="32" style="width:90px;"> ' +
          '<button ng-click="addProfile()" ng-disabled="!newProfile">Add</button>' +
          '<div style="opacity:0.6;">e.g. one per PC; only this machine switches</div>' +
        '</div>' +
        '<label ng-repeat="c in categories" style="display:block; margin-bottom:3px;">' +
          '<input type="checkbox" ng-model="selection[c.id]" ng-change="saveSelection()"> {{c.label}}' +
          '<div style="opacity:0.6; margin-left:20px;">{{c.backupDate ? (c.backupCount + (c.backupCount === 1 ? " file, " : " files, ") + c.backupDate) : "no backup yet"}}</div>' +
        '</label>' +
        '<div style="margin-top:6px;">' +
          '<button ng-click="run(\'exportAll\')">Export</button> ' +
          '<button ng-click="run(\'importAll\')">Import</button>' +
        '</div>' +
        '<div style="margin-top:6px; opacity:0.6;">Current: {{current || "no backup yet"}}</div>' +
        '<div style="margin-top:4px;" ng-show="history.length">Older ' +
          '<select ng-model="restore.id" ng-options="b.id as b.label for b in history" style="max-width:190px;">' +
            '<option value="">choose backup</option></select> ' +
          '<button ng-click="restoreBackup()" ng-disabled="!restore.id">Restore</button>' +
        '</div>' +
        '<label style="display:block; margin-top:6px;">' +
          '<input type="checkbox" ng-model="autoImport" ng-change="setAutoImport()"> Auto-import at game start' +
          '<div style="opacity:0.6; margin-left:20px;">when the cloud backup is newer, e.g. on cloud gaming. ' +
          'Fresh machines use profile \'{{autoImportProfile}}\'</div>' +
        '</label>' +
        '<label style="display:block; margin-top:4px;">' +
          '<input type="checkbox" ng-model="autoExport" ng-change="setAutoExport()"> Auto-export changes' +
          '<div style="opacity:0.6; margin-left:20px;">saves all categories within a minute, once this machine has imported or exported</div>' +
        '</label>' +
        '<div style="opacity:0.6; margin-top:6px;">Tip: also in the pause menu under Mods, Export and Import in the radial menu.</div>' +
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
      scope.profiles = []
      scope.profile = ''
      scope.newProfile = ''
      scope.history = []
      scope.restore = { id: '' }
      scope.selection = JSON.parse(localStorage.getItem(storageKey) || 'null') || {}

      // Selection as a Lua table, e.g. {controls=true,otherSettings=false}
      function selectionToLua () {
        return '{' + Object.keys(scope.selection).map(function (k) {
          return k + '=' + (scope.selection[k] ? 'true' : 'false')
        }).join(',') + '}'
      }

      scope.refresh = function () {
        bngApi.engineLua('settingsCloudSync.getStatus()', function (data) {
          scope.$evalAsync(function () {
            data = data || {}
            scope.categories = data.categories || []
            scope.autoImport = data.autoImport === true
            scope.autoExport = data.autoExport === true
            scope.autoImportProfile = data.autoImportProfile
            scope.profiles = data.profiles || []
            scope.profile = data.profile
            scope.version = data.version
            scope.current = data.current
            scope.history = Array.isArray(data.history) ? data.history : []
            scope.categories.forEach(function (c) {
              if (scope.selection[c.id] === undefined) scope.selection[c.id] = true
            })
          })
        })
      }

      scope.toggleCollapsed = function () {
        scope.collapsed = !scope.collapsed
        localStorage.setItem(collapsedKey, scope.collapsed ? 'true' : 'false')
      }

      scope.saveSelection = function () {
        localStorage.setItem(storageKey, JSON.stringify(scope.selection))
      }

      // The option lives in the cloud (not in localStorage) so it reaches a fresh machine
      scope.setAutoImport = function () {
        bngApi.engineLua('settingsCloudSync.setAutoImport(' + (scope.autoImport ? 'true' : 'false') + ')')
      }

      scope.setAutoExport = function () {
        bngApi.engineLua('settingsCloudSync.setAutoExport(' + (scope.autoExport ? 'true' : 'false') + ')')
      }

      // Allowed characters only, so the name stays a valid Lua string
      scope.setProfile = function (name) {
        name = String(name || '').replace(/[^A-Za-z0-9 _-]/g, '')
        bngApi.engineLua('settingsCloudSync.setProfile("' + name + '")')
        setTimeout(scope.refresh, 300)
      }

      scope.addProfile = function () {
        scope.setProfile(scope.newProfile)
        scope.newProfile = ''
      }

      // Restores the backup and makes it the current one; the previous one moves into the history
      scope.restoreBackup = function () {
        var id = String(scope.restore.id || '').replace(/[^A-Za-z0-9-]/g, '')
        if (!id) return
        bngApi.engineLua('settingsCloudSync.restoreBackup("' + id + '")')
        scope.restore.id = ''
        setTimeout(scope.refresh, 800)
      }

      scope.run = function (fn) {
        bngApi.engineLua('settingsCloudSync.' + fn + '(' + selectionToLua() + ')')
        setTimeout(scope.refresh, 500)
      }

      scope.refresh()
    }
  }
}])
