const assert = require("assert")
const Model = require("../Model.js")

function test(name, fn) {
  fn()
  console.log("ok", name)
}

test("default config has five numbered workspaces", () => {
  const cfg = Model.defaultConfig()
  assert.strictEqual(cfg.workspaces.length, 5)
  assert.strictEqual(cfg.followOnLaunch, true)
  assert.strictEqual(cfg.workspaces[0].workspace, 1)
})

test("parseConfig creates defaults for empty input", () => {
  const parsed = Model.parseConfig("")
  assert.strictEqual(parsed.ok, true)
  assert.strictEqual(parsed.created, true)
  assert.strictEqual(parsed.config.workspaces.length, 5)
})

test("parseConfig rejects invalid JSON", () => {
  const parsed = Model.parseConfig("{nope")
  assert.strictEqual(parsed.ok, false)
  assert.match(parsed.error, /JSON/)
})

test("add, rename, and renumber workspaces", () => {
  let cfg = Model.defaultConfig()
  cfg = Model.addWorkspace(cfg, "Comm", 1)
  const comm = cfg.workspaces.find((ws) => ws.name === "Comm")
  assert.ok(comm)
  cfg = Model.renameWorkspace(cfg, comm.id, "Chat")
  assert.strictEqual(Model.findWorkspace(cfg, comm.id).name, "Chat")
  cfg = Model.setWorkspaceNumber(cfg, comm.id, 8)
  assert.strictEqual(Model.findWorkspace(cfg, comm.id).workspace, 8)
})

test("workspace numbers clamp to 1-10", () => {
  assert.strictEqual(Model.clampWorkspace(0), 1)
  assert.strictEqual(Model.clampWorkspace(99), 10)
})

test("apps move uniquely to the assigned workspace", () => {
  let cfg = Model.defaultConfig()
  const first = cfg.workspaces[0].id
  const second = cfg.workspaces[1].id
  cfg = Model.addApp(cfg, first, { name: "Slack", class: "Slack", desktopId: "slack" })
  cfg = Model.addApp(cfg, second, { name: "Slack", class: "Slack", desktopId: "slack" })
  assert.strictEqual(Model.findWorkspace(cfg, first).apps.length, 0)
  assert.strictEqual(Model.findWorkspace(cfg, second).apps.length, 1)
})

test("duplicate app assignment is ignored", () => {
  let cfg = Model.defaultConfig()
  const id = cfg.workspaces[0].id
  cfg = Model.addApp(cfg, id, { name: "Slack", class: "Slack", desktopId: "slack" })
  cfg = Model.addApp(cfg, id, { name: "Slack", class: "Slack", desktopId: "slack" })
  assert.strictEqual(cfg.workspaces[0].apps.length, 1)
})

test("removeApp deletes only that assignment", () => {
  let cfg = Model.defaultConfig()
  const id = cfg.workspaces[0].id
  cfg = Model.addApp(cfg, id, { name: "Slack", class: "Slack", desktopId: "slack" })
  const appId = cfg.workspaces[0].apps[0].id
  cfg = Model.removeApp(cfg, id, appId)
  assert.strictEqual(cfg.workspaces[0].apps.length, 0)
})

test("generateLua writes follow and silent workspace rules", () => {
  let cfg = Model.defaultConfig()
  cfg = Model.addApp(cfg, cfg.workspaces[0].id, { name: "Slack", class: "Slack", desktopId: "slack" })
  const follow = Model.generateLua(cfg)
  assert.match(follow, /o\.window\(\{ class = "\^Slack\$" \}, \{ workspace = "1" \}\)/)
  const silent = Model.generateLua(Model.setFollowOnLaunch(cfg, false))
  assert.match(silent, /workspace = "1 silent"/)
})

test("generateLua escapes regex metacharacters", () => {
  let cfg = Model.defaultConfig()
  cfg = Model.addApp(cfg, cfg.workspaces[0].id, { name: "App", class: "org.foo+bar", desktopId: "foo" })
  const lua = Model.generateLua(cfg)
  assert.match(lua, /org\\\\\.foo\\\\\+bar/)
})

test("title-only windows still generate a rule", () => {
  const app = Model.appFromWindow({ class: "", title: "Secret Chat" })
  assert.strictEqual(app.title, "Secret Chat")
  let cfg = Model.defaultConfig()
  cfg = Model.addApp(cfg, cfg.workspaces[0].id, app)
  assert.match(Model.generateLua(cfg), /title = "\^Secret Chat\$"/)
})

test("apps without a class or title are rejected", () => {
  let cfg = Model.defaultConfig()
  cfg = Model.addApp(cfg, cfg.workspaces[0].id, { name: "Ghost" })
  assert.strictEqual(cfg.workspaces[0].apps.length, 0)
})

test("an eleventh workspace is refused once 1-10 are taken", () => {
  let cfg = Model.defaultConfig()
  for (let n = 6; n <= 10; n++) cfg = Model.addWorkspace(cfg, String(n), n)
  const before = cfg.workspaces.length
  cfg = Model.addWorkspace(cfg, "Overflow")
  assert.strictEqual(cfg.workspaces.length, before)
})

test("parseActiveWindow and parseClients", () => {
  const window = Model.parseActiveWindow(JSON.stringify({
    class: "Slack",
    title: "Slack",
    address: "0x1",
    workspace: { id: 1 }
  }))
  assert.strictEqual(window.class, "Slack")
  const clients = Model.parseClients(JSON.stringify([
    { class: "Slack", title: "Slack", address: "0x1", workspace: { id: 1 } },
    { class: "Code", title: "main.rs", address: "0x2", workspace: { id: 2 } }
  ]))
  assert.strictEqual(clients.length, 2)
  assert.strictEqual(Model.workspaceOccupied(clients, 2), true)
  assert.strictEqual(Model.workspaceOccupied(clients, 4), false)
})

test("launch and focus commands stay quoted", () => {
  const focus = Model.focusCommand(3)
  assert.match(focus, /hyprctl dispatch/)
  assert.match(focus, /workspace = "3"/)
  const launch = Model.launchCommand({ class: "Slack", desktopId: "slack", name: "Slack" })
  assert.match(launch, /omarchy-launch-or-focus/)
  assert.match(launch, /gtk-launch/)
})

test("desktopOptions skip hidden entries and duplicates", () => {
  const options = Model.desktopOptions([
    { id: "slack", name: "Slack", startupClass: "Slack" },
    { id: "slack", name: "Slack Duplicate", startupClass: "Slack" },
    { id: "hidden", name: "Hidden", startupClass: "Hidden", noDisplay: true }
  ])
  assert.strictEqual(options.length, 1)
  assert.strictEqual(options[0].value, "slack")
})

console.log("\nAll model tests passed.")
