var PLUGIN_ID = "io.github.jethrojones.tile-manager"
var CONFIG_VERSION = 1
var MIN_WORKSPACE = 1
var MAX_WORKSPACE = 10
function pluginId() {
  return PLUGIN_ID
}

function defaultConfig() {
  return {
    version: CONFIG_VERSION,
    followOnLaunch: true,
    pinWindows: false,
    hideStockWorkspaces: false,
    autolaunchAtLogin: false,
    workspaces: [
      emptyWorkspace("ws-1", "1", 1),
      emptyWorkspace("ws-2", "2", 2),
      emptyWorkspace("ws-3", "3", 3),
      emptyWorkspace("ws-4", "4", 4),
      emptyWorkspace("ws-5", "5", 5)
    ]
  }
}

function emptyWorkspace(id, name, workspace) {
  return {
    id: String(id),
    name: String(name),
    workspace: clampWorkspace(workspace),
    apps: []
  }
}

function clampWorkspace(value) {
  var n = parseInt(String(value), 10)
  if (!isFinite(n)) n = MIN_WORKSPACE
  return Math.max(MIN_WORKSPACE, Math.min(MAX_WORKSPACE, n))
}

function slugify(value) {
  var text = String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  return text || "item"
}

function uniqueId(prefix, used) {
  var base = slugify(prefix)
  var id = base
  var n = 2
  while (used[id]) {
    id = base + "-" + n
    n += 1
  }
  used[id] = true
  return id
}

function clone(value) {
  return JSON.parse(JSON.stringify(value === undefined ? null : value))
}

function parseConfig(raw) {
  if (raw === undefined || raw === null || raw === "") return { ok: true, config: defaultConfig(), created: true }
  if (typeof raw === "object") return normalizeConfig(raw)
  try {
    return normalizeConfig(JSON.parse(String(raw)))
  } catch (e) {
    return { ok: false, error: "Config is not valid JSON", config: defaultConfig() }
  }
}

function normalizeConfig(raw) {
  var source = raw && typeof raw === "object" ? raw : {}
  var used = {}
  var workspaces = []
  var incoming = Array.isArray(source.workspaces) ? source.workspaces : []

  for (var i = 0; i < incoming.length; i++) {
    var ws = normalizeWorkspace(incoming[i], used)
    if (ws) workspaces.push(ws)
  }

  if (workspaces.length === 0) workspaces = defaultConfig().workspaces

  workspaces = sortByNumber(workspaces)

  return {
    ok: true,
    config: {
      version: CONFIG_VERSION,
      followOnLaunch: source.followOnLaunch !== false,
      pinWindows: source.pinWindows === true,
      hideStockWorkspaces: source.hideStockWorkspaces === true,
      autolaunchAtLogin: source.autolaunchAtLogin === true,
      workspaces: workspaces
    }
  }
}

function normalizeWorkspace(raw, used) {
  if (!raw || typeof raw !== "object") return null
  var name = String(raw.name || raw.label || "").trim()
  if (!name) name = String(raw.workspace || raw.id || "Workspace")
  var id = uniqueId(raw.id || name, used)
  var apps = []
  var appUsed = {}
  var incoming = Array.isArray(raw.apps) ? raw.apps : []
  for (var i = 0; i < incoming.length; i++) {
    var app = normalizeApp(incoming[i], appUsed)
    if (app) apps.push(app)
  }
  return {
    id: id,
    name: name.slice(0, 24),
    workspace: clampWorkspace(raw.workspace),
    apps: apps
  }
}

function normalizeApp(raw, used) {
  if (!raw || typeof raw !== "object") return null
  var name = String(raw.name || raw.label || raw.desktopId || raw.class || "").trim()
  var desktopId = normalizeDesktopId(raw.desktopId || "")
  var klass = String(raw.class || raw.startupClass || "").trim()
  var title = String(raw.title || "").trim()
  if (!name && !desktopId && !klass) return null
  if (!name) name = desktopId || klass
  var id = uniqueId(raw.id || desktopId || klass || name, used)
  return {
    id: id,
    name: name.slice(0, 48),
    desktopId: desktopId,
    class: klass,
    title: title
  }
}

function normalizeDesktopId(id) {
  var value = String(id || "").trim()
  if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
  return value
}

function findWorkspace(config, workspaceId) {
  var workspaces = config && config.workspaces ? config.workspaces : []
  for (var i = 0; i < workspaces.length; i++) {
    if (workspaces[i].id === workspaceId) return workspaces[i]
  }
  return null
}

function addWorkspace(config, name, workspace) {
  var next = clone(config)
  var number = workspace || nextFreeNumber(next)
  if (!number) return next
  var used = idsInUse(next.workspaces)
  var label = String(name || "").trim() || String(number)
  var ws = emptyWorkspace(uniqueId(label, used), label.slice(0, 24), number)
  next.workspaces = insertByNumber(next.workspaces, ws)
  return next
}

function sortByNumber(workspaces) {
  return (workspaces || []).slice().sort(function(left, right) {
    return left.workspace - right.workspace
  })
}

function insertByNumber(workspaces, ws) {
  var out = []
  var inserted = false
  for (var i = 0; i < workspaces.length; i++) {
    if (!inserted && workspaces[i].workspace > ws.workspace) {
      out.push(ws)
      inserted = true
    }
    out.push(workspaces[i])
  }
  if (!inserted) out.push(ws)
  return out
}

function liveWorkspaceIds(hyprlandIds, clients, focusedId) {
  var seen = {}
  var values = hyprlandIds || []
  for (var i = 0; i < values.length; i++) {
    var id = parseInt(String(values[i]), 10)
    if (id >= MIN_WORKSPACE && id <= MAX_WORKSPACE) seen[id] = true
  }
  var focus = parseInt(String(focusedId), 10)
  if (focus >= MIN_WORKSPACE && focus <= MAX_WORKSPACE) seen[focus] = true
  var list = clients || []
  for (var c = 0; c < list.length; c++) {
    var ws = parseInt(String(list[c].workspace), 10)
    if (ws >= MIN_WORKSPACE && ws <= MAX_WORKSPACE) seen[ws] = true
  }
  var ids = []
  for (var key in seen) ids.push(parseInt(key, 10))
  ids.sort(function(a, b) { return a - b })
  return ids
}

function barWorkspaces(config, focusedId, liveIds) {
  var ids = [1, 2, 3, 4, 5]
  var live = liveIds || []
  var focus = parseInt(String(focusedId), 10)
  for (var i = 0; i < live.length; i++) {
    var id = parseInt(String(live[i]), 10)
    if (id >= 6 && id <= MAX_WORKSPACE && ids.indexOf(id) === -1) ids.push(id)
  }
  if (focus >= 6 && focus <= MAX_WORKSPACE && ids.indexOf(focus) === -1) ids.push(focus)
  ids.sort(function(left, right) { return left - right })
  var result = []
  for (var n = 0; n < ids.length; n++) {
    var ws = findWorkspaceByNumber(config, ids[n])
    result.push(ws || emptyWorkspace("ws-" + ids[n], String(ids[n]), ids[n]))
  }
  return result
}

function mergeLiveWorkspaces(config, liveIds) {
  var next = clone(config)
  var added = false
  var ids = liveIds || []
  for (var i = 0; i < ids.length; i++) {
    var number = clampWorkspace(ids[i])
    if (findWorkspaceByNumber(next, number)) continue
    var used = idsInUse(next.workspaces)
    next.workspaces = insertByNumber(next.workspaces, emptyWorkspace(uniqueId("ws-" + number, used), String(number), number))
    added = true
  }
  var before = next.workspaces.map(function(ws) { return ws.id }).join(",")
  next.workspaces = sortByNumber(next.workspaces)
  var sorted = before !== next.workspaces.map(function(ws) { return ws.id }).join(",")
  return { config: next, added: added, changed: added || sorted }
}

function nextFreeNumber(config) {
  var used = {}
  var workspaces = config.workspaces || []
  for (var i = 0; i < workspaces.length; i++) used[workspaces[i].workspace] = true
  for (var n = MIN_WORKSPACE; n <= MAX_WORKSPACE; n++) {
    if (!used[n]) return n
  }
  return 0
}

function idsInUse(items) {
  var used = {}
  for (var i = 0; i < items.length; i++) used[items[i].id] = true
  return used
}

function renameWorkspace(config, workspaceId, name) {
  var next = clone(config)
  var ws = findWorkspace(next, workspaceId)
  if (!ws) return next
  var label = String(name || "").trim()
  if (label) ws.name = label.slice(0, 24)
  return next
}

function setWorkspaceNumber(config, workspaceId, workspace) {
  var next = clone(config)
  var ws = findWorkspace(next, workspaceId)
  if (!ws) return next
  ws.workspace = clampWorkspace(workspace)
  return next
}

function removeWorkspace(config, workspaceId) {
  var next = clone(config)
  next.workspaces = next.workspaces.filter(function(ws) { return ws.id !== workspaceId })
  if (next.workspaces.length === 0) next.workspaces = defaultConfig().workspaces
  return next
}

function addApp(config, workspaceId, app) {
  var next = clone(config)
  var ws = findWorkspace(next, workspaceId)
  if (!ws) return next
  var used = idsInUse(ws.apps)
  var normalized = normalizeApp(app, used)
  if (!normalized || !appHasMatch(normalized)) return next
  for (var i = 0; i < ws.apps.length; i++) {
    if (sameApp(ws.apps[i], normalized)) return next
  }
  removeAppEverywhere(next, normalized)
  ws = findWorkspace(next, workspaceId)
  ws.apps.push(normalized)
  return next
}

function appHasMatch(app) {
  return !!(app && (app.class || app.title))
}

function sameApp(left, right) {
  if (left.desktopId && right.desktopId && left.desktopId === right.desktopId) return true
  if (left.class && right.class && left.class.toLowerCase() === right.class.toLowerCase()) return true
  return false
}

function removeAppEverywhere(config, app) {
  for (var i = 0; i < config.workspaces.length; i++) {
    config.workspaces[i].apps = config.workspaces[i].apps.filter(function(existing) {
      return !sameApp(existing, app)
    })
  }
}

function removeApp(config, workspaceId, appId) {
  var next = clone(config)
  var ws = findWorkspace(next, workspaceId)
  if (!ws) return next
  ws.apps = ws.apps.filter(function(app) { return app.id !== appId })
  return next
}

function setFollowOnLaunch(config, enabled) {
  var next = clone(config)
  next.followOnLaunch = enabled !== false
  return next
}

function setPinWindows(config, enabled) {
  var next = clone(config)
  next.pinWindows = enabled === true
  return next
}

function setHideStockWorkspaces(config, enabled) {
  var next = clone(config)
  next.hideStockWorkspaces = enabled === true
  return next
}

function setAutolaunchAtLogin(config, enabled) {
  var next = clone(config)
  next.autolaunchAtLogin = enabled === true
  return next
}

function hideStockWorkspacesCommand() {
  return "omarchy plugin disable omarchy.workspaces"
}

function showStockWorkspacesCommand() {
  return "omarchy plugin enable omarchy.workspaces --section left --before " + PLUGIN_ID
}

function findWorkspaceByNumber(config, number) {
  var target = clampWorkspace(number)
  var workspaces = config && config.workspaces ? config.workspaces : []
  for (var i = 0; i < workspaces.length; i++) {
    if (workspaces[i].workspace === target) return workspaces[i]
  }
  return null
}

function ensureWorkspaceNumber(config, number) {
  var next = clone(config)
  var target = clampWorkspace(number)
  if (findWorkspaceByNumber(next, target)) return next
  var used = idsInUse(next.workspaces)
  next.workspaces = insertByNumber(next.workspaces, emptyWorkspace(uniqueId("ws-" + target, used), String(target), target))
  return next
}

function escapeRe2(value) {
  return String(value || "").replace(/[\\^$.|?*+()\[\]{}]/g, "\\$&")
}

function escapeLuaString(value) {
  return String(value || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")
}

function exactClassPattern(klass) {
  return "^" + escapeRe2(klass) + "$"
}

function workspaceEffect(number, followOnLaunch) {
  return followOnLaunch === false ? String(number) + " silent" : String(number)
}

function appMatch(app) {
  var match = {}
  if (app.class) match.class = exactClassPattern(app.class)
  if (app.title) match.title = exactClassPattern(app.title)
  return match
}

function generateLua(config) {
  var lines = [
    "-- Generated by " + PLUGIN_ID + ". Do not edit.",
    "-- Source of truth: ~/.config/omarchy/tile-manager.json",
    ""
  ]
  var follow = !config || config.followOnLaunch !== false
  var workspaces = config && config.workspaces ? config.workspaces : []
  var wrote = false

  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i]
    for (var j = 0; j < ws.apps.length; j++) {
      var app = ws.apps[j]
      var match = appMatch(app)
      if (!match.class && !match.title) continue
      wrote = true
      lines.push(luaWindowRule(app, ws, match, follow))
    }
  }

  if (!wrote) lines.push("-- No app assignments yet.")
  lines.push("")
  return lines.join("\n")
}

function luaWindowRule(app, ws, match, follow) {
  var parts = []
  if (match.class) parts.push('class = "' + escapeLuaString(match.class) + '"')
  if (match.title) parts.push('title = "' + escapeLuaString(match.title) + '"')
  return 'o.window({ ' + parts.join(", ") + ' }, { workspace = "' + escapeLuaString(workspaceEffect(ws.workspace, follow)) + '" }) -- ' + escapeLuaString(app.name)
}

function parseJsonProcess(raw) {
  try {
    return JSON.parse(String(raw || ""))
  } catch (e) {
    return null
  }
}

function parseActiveWindow(raw) {
  var data = parseJsonProcess(raw)
  if (!data || typeof data !== "object" || Array.isArray(data)) return null
  if (!data.class && !data.title && !data.address) return null
  return {
    class: String(data.class || ""),
    initialClass: String(data.initialClass || ""),
    title: String(data.title || ""),
    address: String(data.address || ""),
    workspace: data.workspace && data.workspace.id ? data.workspace.id : 0,
    focusHistoryID: 0
  }
}

function focusedClient(clients) {
  var best = null
  var list = clients || []
  for (var i = 0; i < list.length; i++) {
    if (!best || list[i].focusHistoryID < best.focusHistoryID) best = list[i]
  }
  return best
}

function parseClients(raw) {
  var data = parseJsonProcess(raw)
  if (!Array.isArray(data)) return []
  var clients = []
  for (var i = 0; i < data.length; i++) {
    var item = data[i]
    if (!item) continue
    var focusId = parseInt(String(item.focusHistoryID), 10)
    clients.push({
      class: String(item.class || ""),
      initialClass: String(item.initialClass || ""),
      title: String(item.title || ""),
      address: String(item.address || ""),
      workspace: item.workspace && item.workspace.id ? item.workspace.id : 0,
      focusHistoryID: isFinite(focusId) ? focusId : 9999
    })
  }
  return clients
}

function workspaceOccupied(clients, workspaceNumber) {
  for (var i = 0; i < clients.length; i++) {
    if (clients[i].workspace === workspaceNumber) return true
  }
  return false
}

function findAssignedWorkspaceForClass(config, klass) {
  return findAssignedWorkspaceForWindow(config, { class: klass })
}

function findAssignedWorkspaceForWindow(config, window) {
  if (!window) return null
  var classNeedle = String(window.class || window.initialClass || "").toLowerCase()
  var titleNeedle = String(window.title || "").toLowerCase()
  var workspaces = config && config.workspaces ? config.workspaces : []
  for (var i = 0; i < workspaces.length; i++) {
    var apps = workspaces[i].apps || []
    for (var j = 0; j < apps.length; j++) {
      var appClass = String(apps[j].class || "").toLowerCase()
      var appTitle = String(apps[j].title || "").toLowerCase()
      if (classNeedle && appClass && appClass === classNeedle) return workspaces[i]
      if (titleNeedle && appTitle && appTitle === titleNeedle) return workspaces[i]
    }
  }
  return null
}

function appFromDesktopEntry(entry) {
  if (!entry) return null
  var desktopId = normalizeDesktopId(entry.id || "")
  var klass = String(entry.startupClass || "").trim()
  var name = String(entry.name || desktopId || "").trim()
  if (!desktopId && !klass && !name) return null
  return {
    name: name || desktopId || klass,
    desktopId: desktopId,
    class: klass || desktopId,
    title: ""
  }
}

function friendlyAppName(klass, title) {
  var lower = String(klass || "").toLowerCase()
  if (lower.indexOf("discord") !== -1) return "Discord"
  if (lower.indexOf("telegram") !== -1) return "Telegram"
  if (lower.indexOf("beeper") !== -1) return "Beeper"
  if (lower.indexOf("hey.com") !== -1) return "Hey"
  if (lower.indexOf("chatgpt") !== -1) return "ChatGPT"
  if (lower.indexOf("btop") !== -1) return "btop"
  if (lower === "chromium" || lower.indexOf("google-chrome") !== -1) return "Chromium"
  var label = String(title || "").trim()
  if (label && label.length <= 28 && label.indexOf(" | ") === -1) return label
  return klass || label
}

function appFromWindow(window) {
  if (!window) return null
  var klass = String(window.class || window.initialClass || "").trim()
  var title = String(window.title || "").trim()
  if (!klass && !title) return null
  var name = friendlyAppName(klass, title)
  return {
    name: name,
    desktopId: "",
    class: klass,
    title: klass ? "" : title
  }
}

function importOpenWindows(config, clients) {
  var next = clone(config)
  var classWorkspaces = {}
  var classSample = {}
  var list = clients || []
  for (var i = 0; i < list.length; i++) {
    var client = list[i]
    var klass = String(client.class || client.initialClass || "").trim()
    if (!klass || !client.workspace) continue
    if (!classWorkspaces[klass]) classWorkspaces[klass] = {}
    classWorkspaces[klass][client.workspace] = true
    classSample[klass] = client
  }
  var names = Object.keys(classWorkspaces)
  for (var n = 0; n < names.length; n++) {
    var className = names[n]
    var numbers = Object.keys(classWorkspaces[className])
    if (numbers.length !== 1) continue
    var number = parseInt(numbers[0], 10)
    next = ensureWorkspaceNumber(next, number)
    var ws = findWorkspaceByNumber(next, number)
    if (!ws) continue
    next = addApp(next, ws.id, appFromWindow(classSample[className]))
  }
  return next
}

function focusCommand(workspaceNumber) {
  var id = clampWorkspace(workspaceNumber)
  return "hyprctl dispatch " + shellQuote('hl.dsp.focus({ workspace = "' + id + '" })')
}

function windowAddress(address) {
  var value = String(address || "").trim()
  if (!value) return ""
  if (value.indexOf("address:") === 0) return value
  if (value.indexOf("0x") === 0) return "address:" + value
  return "address:" + value
}

function moveCommand(address, workspace, follow) {
  var target = windowAddress(address)
  if (!target) return ""
  var spec = follow === false
    ? 'hl.dsp.window.move({ workspace = "' + clampWorkspace(workspace) + '", follow = false, window = "' + target + '" })'
    : 'hl.dsp.window.move({ workspace = "' + clampWorkspace(workspace) + '", window = "' + target + '" })'
  return "hyprctl dispatch " + shellQuote(spec)
}

function eventParts(event, count) {
  if (event && typeof event.parse === "function") {
    try { return event.parse(count) } catch (e) {}
  }
  return String(event && event.data ? event.data : "").split(",")
}

function windowFromOpenEvent(event) {
  var parts = eventParts(event, 4)
  return {
    address: String(parts[0] || ""),
    workspace: parseInt(String(parts[1] || ""), 10) || 0,
    class: String(parts[2] || ""),
    title: String(parts.slice(3).join(",") || "")
  }
}

function launchCommand(app) {
  var pattern = escapeRe2(app.class || app.desktopId || app.name || "")
  var launch = startCommand(app)
  if (!pattern || !launch) return launch
  return "omarchy-launch-or-focus " + shellQuote(pattern) + " " + shellQuote(launch)
}

function startCommand(app) {
  if (!app) return ""
  if (app.desktopId) return "uwsm-app -- gtk-launch " + shellQuote(app.desktopId + ".desktop")
  if (app.class) return "uwsm-app -- " + shellQuote(app.class)
  return ""
}

function appIsRunning(app, clients) {
  if (!app) return false
  var klass = String(app.class || "").toLowerCase()
  var desktop = String(app.desktopId || "").toLowerCase()
  var list = clients || []
  for (var i = 0; i < list.length; i++) {
    var running = String(list[i].class || list[i].initialClass || "").toLowerCase()
    if (klass && running === klass) return true
    if (desktop && running === desktop) return true
  }
  return false
}

function startIfMissingCommand(app, clients) {
  if (appIsRunning(app, clients)) return ""
  return startCommand(app)
}

function shellQuote(value) {
  return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
}

function desktopOptions(entries) {
  var options = []
  var seen = {}
  var list = entries || []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i].entry ? list[i].entry : list[i]
    if (!entry || entry.noDisplay) continue
    var app = appFromDesktopEntry(entry)
    if (!app || !app.desktopId || seen[app.desktopId]) continue
    seen[app.desktopId] = true
    options.push({
      value: app.desktopId,
      label: app.name,
      description: app.class || app.desktopId,
      app: app
    })
  }
  options.sort(function(a, b) { return a.label.toLowerCase() < b.label.toLowerCase() ? -1 : 1 })
  return options
}

function workspaceIdsKey(workspaces) {
  return (workspaces || []).map(function(ws) { return ws.id }).join(",")
}

function rawWorkspaceIdsKey(raw) {
  var data = raw
  if (typeof raw === "string") {
    try { data = JSON.parse(raw) } catch (e) { return "" }
  }
  if (!data || !Array.isArray(data.workspaces)) return ""
  return workspaceIdsKey(data.workspaces)
}

function stringifyConfig(config) {
  return JSON.stringify(config, null, 2) + "\n"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    PLUGIN_ID: PLUGIN_ID,
    defaultConfig: defaultConfig,
    parseConfig: parseConfig,
    normalizeConfig: normalizeConfig,
    addWorkspace: addWorkspace,
    renameWorkspace: renameWorkspace,
    setWorkspaceNumber: setWorkspaceNumber,
    removeWorkspace: removeWorkspace,
    addApp: addApp,
    removeApp: removeApp,
    setFollowOnLaunch: setFollowOnLaunch,
    setPinWindows: setPinWindows,
    setHideStockWorkspaces: setHideStockWorkspaces,
    setAutolaunchAtLogin: setAutolaunchAtLogin,
    mergeLiveWorkspaces: mergeLiveWorkspaces,
    barWorkspaces: barWorkspaces,
    liveWorkspaceIds: liveWorkspaceIds,
    hideStockWorkspacesCommand: hideStockWorkspacesCommand,
    showStockWorkspacesCommand: showStockWorkspacesCommand,
    findWorkspace: findWorkspace,
    findWorkspaceByNumber: findWorkspaceByNumber,
    ensureWorkspaceNumber: ensureWorkspaceNumber,
    escapeRe2: escapeRe2,
    escapeLuaString: escapeLuaString,
    generateLua: generateLua,
    parseActiveWindow: parseActiveWindow,
    parseClients: parseClients,
    focusedClient: focusedClient,
    workspaceOccupied: workspaceOccupied,
    findAssignedWorkspaceForClass: findAssignedWorkspaceForClass,
    findAssignedWorkspaceForWindow: findAssignedWorkspaceForWindow,
    appFromDesktopEntry: appFromDesktopEntry,
    appFromWindow: appFromWindow,
    importOpenWindows: importOpenWindows,
    focusCommand: focusCommand,
    moveCommand: moveCommand,
    windowFromOpenEvent: windowFromOpenEvent,
    launchCommand: launchCommand,
    startCommand: startCommand,
    startIfMissingCommand: startIfMissingCommand,
    appIsRunning: appIsRunning,
    desktopOptions: desktopOptions,
    workspaceIdsKey: workspaceIdsKey,
    rawWorkspaceIdsKey: rawWorkspaceIdsKey,
    stringifyConfig: stringifyConfig,
    clampWorkspace: clampWorkspace
  }
}
