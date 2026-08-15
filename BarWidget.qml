import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.jethrojones.tile-manager"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property var workspaces: service.workspaces
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
        required property var modelData

        readonly property bool occupied: service.occupied(modelData.workspace)
        readonly property bool focused: service.focusedWorkspaceId === modelData.workspace

        implicitWidth: wsButton.implicitWidth
        implicitHeight: wsButton.implicitHeight

        WidgetButton {
          id: wsButton
          anchors.fill: parent
          bar: root.bar
          text: modelData.name
          active: focused
          tooltipText: "Workspace " + modelData.workspace + (modelData.apps.length ? " · " + modelData.apps.length + " apps" : "")
          opacity: occupied || focused ? 1 : 0.5
          horizontalMargin: 6
          verticalPadding: 6
          fixedWidth: root.vertical ? root.barSize : -1
          fixedHeight: root.barSize
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) {
              root.openWorkspace(modelData.id)
            } else if (buttonCode === Qt.MiddleButton) {
              service.launchWorkspace(modelData.id)
            } else {
              root.focusWorkspace(modelData.workspace)
            }
          }
        }

        Rectangle {
          visible: parent.focused && !root.vertical
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(2)
          width: Math.max(Style.space(10), wsButton.labelWidth)
          height: Style.space(2)
          radius: height / 2
          color: Color.accent
        }

        Rectangle {
          visible: parent.focused && root.vertical
          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.right
          anchors.rightMargin: Style.space(2)
          width: Style.space(2)
          height: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
          radius: width / 2
          color: Color.accent
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

      Rectangle {
        visible: root.opened && !root.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(2)
        width: Math.max(Style.space(10), manageButton.labelWidth)
        height: Style.space(2)
        radius: height / 2
        color: Color.accent
      }
    }
  }
}
