import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.jethrojones.tile-manager"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property var workspaces: service.barWorkspaces
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  // Hide the bar host's centered mark — this widget is a row of names, so a
  // slot-wide 55% pill lands under the middle numbers instead of the active one.
  readonly property real openPanelIndicatorWidth: 0.01
  readonly property real openPanelIndicatorHeight: 0.01

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function openWorkspace(workspaceId) {
    if (panelLoader.item && panelLoader.item.openWorkspace)
      panelLoader.item.openWorkspace(workspaceId)
    else
      root.open()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = manageButton
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = service
  }

  function focusWorkspace(number) {
    service.focusWorkspace(number)
  }

  implicitWidth: row.implicitWidth + trailingGap
  implicitHeight: row.implicitHeight

  onBarChanged: {
    service.barRunner = root.bar ? function(command) { root.bar.run(command) } : null
    injectPanel()
  }
  onSettingsChanged: injectPanel()

  Service {
    id: service
    settings: root.settings
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.jethrojones.tile-manager"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  GridLayout {
    id: row
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaces.length + 1
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaces

      Item {
        id: workspaceChip

        readonly property var workspace: modelData
        readonly property int workspaceNumber: workspace && workspace.workspace ? workspace.workspace : 0
        readonly property bool occupied: service.occupied(workspaceNumber)
        readonly property bool focused: {
          var current = service.focusedWorkspaceId
          if (!current && Hyprland.focusedWorkspace) current = Hyprland.focusedWorkspace.id
          return current === workspaceNumber
        }
        readonly property color mark: Color.flatColor(
          Color.pick("hyprland.active-border", Color.accent),
          Color.accent
        )

        implicitWidth: wsButton.implicitWidth
        implicitHeight: wsButton.implicitHeight

        WidgetButton {
          id: wsButton
          anchors.fill: parent
          bar: root.bar
          text: workspace && workspace.name ? workspace.name : ""
          active: workspaceChip.focused
          activeColor: workspaceChip.mark
          tooltipText: "Workspace " + workspaceNumber + (workspace && workspace.apps && workspace.apps.length ? " · " + workspace.apps.length + " apps" : "")
          opacity: workspaceChip.occupied || workspaceChip.focused ? 1 : 0.5
          horizontalMargin: 8
          verticalPadding: 6
          fixedWidth: root.vertical ? root.barSize : -1
          fixedHeight: root.barSize
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) {
              root.openWorkspace(workspace.id)
            } else if (buttonCode === Qt.MiddleButton) {
              service.launchWorkspace(workspace.id)
            } else {
              root.focusWorkspace(workspaceNumber)
            }
          }
        }
      }
    }

    Item {
      implicitWidth: manageButton.implicitWidth
      implicitHeight: manageButton.implicitHeight

      WidgetButton {
        id: manageButton
        anchors.fill: parent
        bar: root.bar
        text: "󰒓"
        tooltipText: "Manage workspace apps"
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.toggle() }
      }
    }
  }
}
