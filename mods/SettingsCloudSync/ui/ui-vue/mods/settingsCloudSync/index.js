// Entry in the pause menu under "Mods", so the settings are reachable without the UI app.
// Same approach as the mod "Extra Controller Layouts" (BeamNG 0.40, ui_pause_actions.registerModButton)
import { lua } from "@/bridge"

const buttonId = "settings-cloud-sync"

export async function onLoad() {
  try {
    await lua.extensions.ui_pause_actions.registerModButton({
      id: buttonId,
      tabId: "mods",
      label: "Settings Cloud Sync",
      icon: "cloud",
      componentName: "/ui/ui-vue/mods/settingsCloudSync/Panel.vue",
    })
  } catch (err) {
    console.warn("Settings Cloud Sync: pause menu entry not available", err)
  }
}

export async function onUnload() {
  try {
    await lua.extensions.ui_pause_actions.unregisterModButton(buttonId)
  } catch (err) {}
}
