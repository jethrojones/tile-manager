import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var config: Model.defaultConfig()
  property var clients: []
  property var activeWindow: null
  property string lastError: ""
  property bool ready: false
  property bool writing: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: {
    var value = Quickshell.env("XDG_STATE_HOME")
    return value && String(value).length ? String(value) : (home + "/.local/state")
  }
  readonly property string configPath: home + "/.config/omarchy/tile-manager.json"
  readonly property string rulesDir: stateHome + "/omarchy/toggles/hypr"
  readonly property string rulesPath: rulesDir + "/tile-manager.lua"
  readonly property string autolaunchPath: stateHome + "/omarchy/tile-manager.autolaunch"
  property string pendingRules: ""
  property string pendingAssignWorkspaceId: ""
  property bool autolaunchChecked: false
  property string currentBootId: ""
  property string lastAutolaunchBootId: ""

  readonly property var workspaces: config && config.workspaces ? config.workspaces : []
  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property var liveIds: {
    var hyprlandIds = []
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) hyprlandIds.push(values[i].id)
    return Model.liveWorkspaceIds(hyprlandIds, root.clients, root.focusedWorkspaceId)
  }
  readonly property var barWorkspaces: Model.barWorkspaces(config, focusedWorkspaceId, liveIds)

  function applyParsed(raw, created) {
    var parsed = Model.parseConfig(raw)
    if (!parsed.ok) {
      root.lastError = parsed.error
      root.config = parsed.config
    } else {
      root.lastError = ""
      root.config = parsed.config
    }
    root.ready = true
    var merged = Model.mergeLiveWorkspaces(root.config, root.liveWorkspaceIds())
    root.config = merged.config
    var orderChanged = Model.rawWorkspaceIdsKey(raw) !== Model.workspaceIdsKey(root.config.workspaces)
    if (created || merged.changed || orderChanged) persist(root.config)
    else syncRules()
  }

  function persist(next) {
    root.config = next
    root.writing = true
    root.lastError = ""
    configFile.setText(Model.stringifyConfig(next))
    syncRules()
  }

  function syncRules() {
    pendingRules = Model.generateLua(root.config)
    if (mkdirProcess.running) return
    mkdirProcess.running = true
  }

  function updateConfig(next) {
    persist(next)
  }

  function addWorkspace(name) {
    persist(Model.addWorkspace(root.config, name))
  }

  function renameWorkspace(workspaceId, name) {
    persist(Model.renameWorkspace(root.config, workspaceId, name))
  }

  function setWorkspaceNumber(workspaceId, number) {
    persist(Model.setWorkspaceNumber(root.config, workspaceId, number))
  }

  function removeWorkspace(workspaceId) {
    persist(Model.removeWorkspace(root.config, workspaceId))
  }

  function addApp(workspaceId, app) {
    persist(Model.addApp(root.config, workspaceId, app))
  }

  function removeApp(workspaceId, appId) {
    persist(Model.removeApp(root.config, workspaceId, appId))
  }

  function setFollowOnLaunch(enabled) {
    persist(Model.setFollowOnLaunch(root.config, enabled))
  }

  function setPinWindows(enabled) {
    persist(Model.setPinWindows(root.config, enabled))
  }

  function setHideStockWorkspaces(enabled) {
    persist(Model.setHideStockWorkspaces(root.config, enabled))
    applyStockWorkspaces(enabled !== true)
  }

  function setAutolaunchAtLogin(enabled) {
    persist(Model.setAutolaunchAtLogin(root.config, enabled))
  }

  function applyStockWorkspaces(show) {
    run(show ? Model.showStockWorkspacesCommand() : Model.hideStockWorkspacesCommand())
  }

  function importOpenWindows() {
    persist(Model.importOpenWindows(root.config, root.clients))
  }

  function liveWorkspaceIds() {
    var hyprlandIds = []
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) hyprlandIds.push(values[i].id)
    return Model.liveWorkspaceIds(hyprlandIds, root.clients, root.focusedWorkspaceId)
  }

  function syncLiveWorkspaces() {
    if (!root.ready || root.writing) return
    var result = Model.mergeLiveWorkspaces(root.config, root.liveWorkspaceIds())
    if (result.changed) persist(result.config)
  }

  function focusWorkspace(number) {
    run(Model.focusCommand(number))
  }

  function launchApp(app) {
    var command = Model.launchCommand(app)
    if (command) run(command)
  }

  function launchMissingAssignedApps() {
    var workspaces = root.config && root.config.workspaces ? root.config.workspaces : []
    for (var i = 0; i < workspaces.length; i++) {
      var apps = workspaces[i].apps || []
      for (var j = 0; j < apps.length; j++) {
        var command = Model.startIfMissingCommand(apps[j], root.clients)
        if (command) run(command)
      }
    }
  }

  function maybeAutolaunch() {
    if (root.autolaunchChecked) return
    if (!root.ready || !root.config || root.config.autolaunchAtLogin !== true) return
    if (!root.currentBootId) return
    if (root.lastAutolaunchBootId === root.currentBootId) {
      root.autolaunchChecked = true
      return
    }
    launchMissingAssignedApps()
    autolaunchFile.setText(root.currentBootId + "\n")
    root.lastAutolaunchBootId = root.currentBootId
    root.autolaunchChecked = true
  }

  function launchWorkspace(workspaceId) {
    var ws = Model.findWorkspace(root.config, workspaceId)
    if (!ws) return
    focusWorkspace(ws.workspace)
    for (var i = 0; i < ws.apps.length; i++) launchApp(ws.apps[i])
  }

  function assignActiveWindow(workspaceId) {
    pendingAssignWorkspaceId = workspaceId
    if (root.clients.length) {
      finishAssignActiveWindow()
      return true
    }
    if (activeProcess.running) return true
    activeProcess.running = true
    return true
  }

  function finishAssignActiveWindow() {
    var workspaceId = pendingAssignWorkspaceId
    if (!workspaceId) return
    pendingAssignWorkspaceId = ""
    var window = Model.focusedClient(root.clients) || root.activeWindow
    var app = Model.appFromWindow(window)
    if (!app || (!app.class && !app.title)) {
      root.lastError = "Focused window has no class or title to match"
      return
    }
    addApp(workspaceId, app)
  }

  function placeWindow(window, follow) {
    var assigned = Model.findAssignedWorkspaceForWindow(root.config, window)
    if (!assigned || !window || !window.address) return false
    if (window.workspace === assigned.workspace) {
      if (follow) focusWorkspace(assigned.workspace)
      return true
    }
    var command = Model.moveCommand(window.address, assigned.workspace, follow !== false)
    if (command) run(command)
    return true
  }

  function enforceAssignments() {
    if (!root.config || root.config.pinWindows === false) return
    var list = root.clients || []
    for (var i = 0; i < list.length; i++) placeWindow(list[i], false)
  }

  function handleHyprlandEvent(event) {
    var name = String(event && event.name ? event.name : "")
    if (name === "openwindow") {
      var opened = Model.windowFromOpenEvent(event)
      placeWindow(opened, root.config.followOnLaunch !== false)
      refreshWindows()
      Qt.callLater(root.syncLiveWorkspaces)
      return
    }
    if (name === "workspace" || name === "createworkspace" || name === "destroyworkspace") {
      root.syncLiveWorkspaces()
      refreshWindows()
      return
    }
    if (name === "movewindow" || name === "movewindowv2" || name === "closewindow") {
      refreshWindows()
      if (root.config.pinWindows !== false) Qt.callLater(root.enforceAssignments)
    }
  }

  function refreshWindows() {
    if (!clientsProcess.running) clientsProcess.running = true
    if (!activeProcess.running) activeProcess.running = true
  }

  function occupied(number) {
    if (Model.workspaceOccupied(root.clients, number)) return true
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === number && values[i].toplevels && values[i].toplevels.values.length > 0)
        return true
    }
    return false
  }

  function run(command) {
    if (root.barRunner)
      root.barRunner(command)
    else
      Util.execDetached(command)
  }

  property var barRunner: null

  function desktopOptions() {
    var values = []
    try { values = DesktopEntries.applications.values || [] } catch (e) { values = [] }
    return Model.desktopOptions(values)
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.writing) root.applyParsed(text(), false)
    onLoadFailed: root.applyParsed("", true)
    onFileChanged: reload()
    onSaved: root.writing = false
  }

  FileView {
    id: autolaunchFile
    path: root.autolaunchPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.lastAutolaunchBootId = String(text() || "").trim()
    onLoadFailed: root.lastAutolaunchBootId = ""
  }

  Process {
    id: bootIdProcess
    running: true
    command: ["cat", "/proc/sys/kernel/random/boot_id"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.currentBootId = String(text || "").trim()
    }
    onExited: root.maybeAutolaunch()
  }

  FileView {
    id: rulesFile
    path: root.rulesPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  Process {
    id: mkdirProcess
    running: false
    command: ["mkdir", "-p", root.rulesDir]
    onExited: {
      rulesFile.setText(root.pendingRules)
      root.reloadHyprland()
    }
  }

  Process {
    id: clientsProcess
    running: false
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.clients = Model.parseClients(text)
    }
    onExited: {
      root.finishAssignActiveWindow()
      root.syncLiveWorkspaces()
      root.maybeAutolaunch()
    }
  }

  Process {
    id: activeProcess
    running: false
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.activeWindow = Model.parseActiveWindow(text)
    }
    onExited: root.finishAssignActiveWindow()
  }

  Process {
    id: reloadProcess
    running: false
    command: ["hyprctl", "reload"]
  }

  function reloadHyprland() {
    if (!reloadProcess.running) reloadProcess.running = true
  }

  Timer {
    interval: 4000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshWindows()
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      root.refreshWindows()
      root.syncLiveWorkspaces()
    }
    function onActiveToplevelChanged() { root.refreshWindows() }
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }
}
