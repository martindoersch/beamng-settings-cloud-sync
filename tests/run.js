// Runs the mod's Lua extension against a mocked BeamNG (in-memory user folder) with the Lua VM fengari.
// Once: cd tests && npm install fengari@0.1.4
// Run:  node tests/run.js tests/settingsCloudSync_test.lua mods/SettingsCloudSync/lua/ge/extensions/settingsCloudSync.lua
// fengari is Lua 5.3, the game uses LuaJIT (5.1): this checks the logic, not every engine detail.
const fs = require('fs')
const { lua, lauxlib, lualib, to_luastring } = require('fengari')
const L = lauxlib.luaL_newstate()
lualib.luaL_openlibs(L)
lua.lua_newtable(L)
process.argv.slice(3).forEach((a, i) => { lua.lua_pushstring(L, to_luastring(a)); lua.lua_rawseti(L, -2, i + 1) })
lua.lua_setglobal(L, to_luastring('arg'))
const src = fs.readFileSync(process.argv[2])
if (lauxlib.luaL_loadbuffer(L, src, null, to_luastring('@' + process.argv[2])) || lua.lua_pcall(L, 0, 0, 0)) {
  console.error('LUA ERROR:', lua.lua_tojsstring(L, -1)); process.exit(1)
}
