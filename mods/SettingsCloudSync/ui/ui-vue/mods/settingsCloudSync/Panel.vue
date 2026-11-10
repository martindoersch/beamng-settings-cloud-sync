<template>
  <section class="scs-panel">
    <h2>Settings Cloud Sync <span v-if="status.version" class="version">v{{ status.version }}</span></h2>
    <p v-if="error" class="error">{{ error }}</p>

    <div class="block">
      <label>Profile</label>
      <div class="row">
        <BngSelect :value="status.profile" :options="profileOptions" :config="selectConfig" @value-changed="setProfile" />
        <input v-model="newProfile" type="text" placeholder="new profile" maxlength="32" />
        <BngButton :disabled="!newProfile" @click="addProfile">Add</BngButton>
      </div>
      <small>e.g. one per PC; only this machine switches</small>
    </div>

    <div class="block">
      <label v-for="c in categories" :key="c.id" class="check">
        <input type="checkbox" v-model="selection[c.id]" @change="saveSelection" /> {{ c.label }}
        <small>{{ c.backupDate ? c.backupCount + (c.backupCount === 1 ? " file, " : " files, ") + c.backupDate : "no backup yet" }}</small>
      </label>
      <div class="row">
        <BngButton @click="run('exportAll')">Export</BngButton>
        <BngButton @click="run('importAll')">Import</BngButton>
      </div>
      <small>Current: {{ status.current || "no backup yet" }}</small>
    </div>

    <div v-if="history.length" class="block">
      <label>Older backups</label>
      <div class="row">
        <BngSelect :value="restoreId" :options="historyOptions" :config="selectConfig" @value-changed="id => (restoreId = id)" />
        <BngButton :disabled="!restoreId" @click="restoreBackup">Restore</BngButton>
      </div>
    </div>

    <div class="block">
      <label class="check">
        <input type="checkbox" :checked="status.autoImport" @change="setOption('setAutoImport', $event.target.checked)" /> Auto-import at game start
        <small>when the cloud backup is newer, e.g. on cloud gaming. Fresh machines use profile '{{ status.autoImportProfile }}'</small>
      </label>
      <label class="check">
        <input type="checkbox" :checked="status.autoExport" @change="setOption('setAutoExport', $event.target.checked)" /> Auto-export changes
        <small>saves all categories within a minute, once this machine has imported or exported</small>
      </label>
    </div>
  </section>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { BngButton, BngSelect } from "@/common/components/base"
import { runRaw } from "@/bridge/libs/Lua"

// Same key as the UI app, so both use the same selection
const storageKey = "settingsCloudSync.selection"

const error = ref("")
const status = ref({})
const newProfile = ref("")
const restoreId = ref("")
const selection = ref(readSelection())

// Empty Lua tables arrive as an object, not as an array
const asList = value => (Array.isArray(value) ? value : Object.values(value || {}))
const categories = computed(() => asList(status.value.categories))
const history = computed(() => asList(status.value.history))
const profileOptions = computed(() => asList(status.value.profiles).map(p => ({ value: p, label: p })))
const historyOptions = computed(() => history.value.map(b => ({ value: b.id, label: b.label })))
const selectConfig = { value: option => option.value, label: option => option.label }

function readSelection() {
  try { return JSON.parse(localStorage.getItem(storageKey) || "null") || {} } catch (err) { return {} }
}

function saveSelection() {
  try { localStorage.setItem(storageKey, JSON.stringify(selection.value)) } catch (err) {}
}

// Selection as a Lua table, e.g. {controls=true,otherSettings=false}
const selectionToLua = () =>
  "{" + Object.keys(selection.value).map(k => k + "=" + (selection.value[k] ? "true" : "false")).join(",") + "}"

const call = async code => {
  try {
    error.value = ""
    return await runRaw("extensions.settingsCloudSync and extensions.settingsCloudSync." + code)
  } catch (err) { error.value = String(err) }
}

const refresh = async () => {
  const data = await call("getStatus()")
  if (!data) { error.value = error.value || "Settings Cloud Sync is unavailable. Restart BeamNG after updating the mod."; return }
  status.value = data
  for (const c of asList(data.categories)) {
    if (selection.value[c.id] === undefined) selection.value[c.id] = true
  }
}

const run = async fn => { await call(fn + "(" + selectionToLua() + ")"); await refresh() }

// The options live in the cloud (config.json) so they reach a fresh machine
const setOption = async (fn, enabled) => { await call(fn + "(" + (enabled ? "true" : "false") + ")"); await refresh() }

// Allowed characters only, so the name stays a valid Lua string
const setProfile = async name => {
  name = String(name || "").replace(/[^A-Za-z0-9 _-]/g, "")
  if (!name) return
  await call('setProfile("' + name + '")')
  await refresh()
}

const addProfile = async () => { await setProfile(newProfile.value); newProfile.value = "" }

// Restores the backup and makes it the current one; the previous one moves into the history
const restoreBackup = async () => {
  const id = String(restoreId.value || "").replace(/[^A-Za-z0-9-]/g, "")
  if (!id) return
  await call('restoreBackup("' + id + '")')
  restoreId.value = ""
  await refresh()
}

onMounted(refresh)
</script>

<style scoped>
.scs-panel { padding: 1.2rem; color: var(--bng-off-white); min-width: 26rem; max-width: 40rem; max-height: 75vh; overflow-y: auto; }
h2 { margin-top: 0; }
.version { font-size: .6em; font-weight: normal; opacity: .6; }
.block { display: grid; gap: .4rem; margin-bottom: 1.2rem; }
.row { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; }
.check { display: block; }
input[type="text"] { width: 9rem; padding: .3rem; }
small { display: block; opacity: .6; margin-top: .2rem; }
.check small { margin-left: 1.6rem; }
.error { color: #ff8a80; }
</style>
