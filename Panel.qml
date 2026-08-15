import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.jethrojones.tile-manager"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  property string selectedId: ""
  property string selectedName: ""
  property string newWorkspaceName: ""
  property string pendingAppId: ""
  property bool editingNumber: false

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.55)
  readonly property var workspaces: service ? service.workspaces : []
  readonly property var selected: service ? Model.findWorkspace(service.config, selectedId || defaultSelectedId()) : null
  property var appOptions: []
  readonly property bool pickerOpen: appPicker.popupOpen
  readonly property bool editingText: newWorkspaceField.activeFocus || renameField.activeFocus || editingNumber

  function defaultSelectedId() {
    return workspaces.length ? workspaces[0].id : ""
  }

  function refreshOptions() {
    appOptions = service ? service.desktopOptions() : []
  }

  function open() {
    if (service) service.refreshWindows()
    refreshOptions()
    selectWorkspace(selectedId || defaultSelectedId())
    root.controller.show()
  }

  function openWorkspace(workspaceId) {
    selectWorkspace(workspaceId || defaultSelectedId())
    open()
  }

  function close() {
    if (appPicker.popupOpen) appPicker.close()
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function selectWorkspace(workspaceId) {
    selectedId = workspaceId
    var ws = service ? Model.findWorkspace(service.config, workspaceId) : null
    selectedName = ws ? ws.name : ""
  }

  function commitSelectedName() {
    if (!service || !selected) return
    var name = String(selectedName || "").trim()
    if (!name || name === selected.name) return
    service.renameWorkspace(selected.id, name)
  }

  function goToWorkspace(number) {
    if (service) service.focusWorkspace(number)
  }

  function launchSelectedWorkspace(workspaceId) {
    if (service) service.launchWorkspace(workspaceId)
  }

  function deleteWorkspace(workspaceId) {
    if (!service) return
    service.removeWorkspace(workspaceId)
    if (selectedId === workspaceId) selectWorkspace(defaultSelectedId())
  }

  function moveWorkspace(workspaceId, delta) {
    if (service) service.moveWorkspace(workspaceId, delta)
  }

  function finishDrag(workspaceId, offsetY, rowHeight) {
    var step = Math.max(Style.space(28), rowHeight || 1)
    var delta = Math.round(offsetY / step)
    if (delta) moveWorkspace(workspaceId, delta)
  }

  function addNamedWorkspace() {
    if (!service) return
    var before = workspaces.map(function(ws) { return ws.id })
    service.addWorkspace(newWorkspaceName)
    newWorkspaceName = ""
    if (newWorkspaceField) newWorkspaceField.text = ""
    Qt.callLater(function() {
      var added = null
      for (var i = 0; i < root.workspaces.length; i++) {
        if (before.indexOf(root.workspaces[i].id) === -1) added = root.workspaces[i]
      }
      if (added) root.selectWorkspace(added.id)
    })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.pickerOpen || root.editingText
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: scroller.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            text: "TILE MANAGER"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            width: parent.width
            text: "Name workspaces and park apps on them. Launching an assigned app follows you there."
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Toggle {
            width: parent.width
            label: "Stock workspace numbers"
            description: "Show Omarchy's 1–0 widget next to Tile Manager"
            checked: service ? service.config.showStockWorkspaces === true : false
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (service) service.setShowStockWorkspaces(!(service.config.showStockWorkspaces === true))
          }

          Toggle {
            width: parent.width
            label: "Follow launches"
            description: "Switch to the app's workspace when it opens"
            checked: service ? service.config.followOnLaunch !== false : true
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (service) service.setFollowOnLaunch(!(service.config.followOnLaunch !== false))
          }

          Toggle {
            width: parent.width
            label: "Keep apps there"
            description: "Move assigned apps back if they leave their workspace"
            checked: service ? service.config.pinWindows === true : false
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (service) service.setPinWindows(!(service.config.pinWindows !== false))
          }

          PanelSeparator { width: parent.width; foreground: root.contentForeground }

          RowLayout {
            width: parent.width

            PanelSectionHeader {
              Layout.fillWidth: true
              text: "Workspaces"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Text {
              visible: service && service.config.sortMode === "manual"
              text: "Sorted by you"
              color: root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            PanelActionButton {
              visible: service && service.config.sortMode === "manual"
              iconText: "󰁞"
              tooltipText: "Sort by workspace number"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (service) service.sortWorkspacesByNumber()
            }
          }

          Repeater {
            model: root.workspaces

            Rectangle {
              id: workspaceCard
              required property var modelData
              width: content.width
              height: workspaceRow.implicitHeight + Style.space(8)
              radius: Style.cornerRadius
              color: modelData.id === root.selectedId
                ? Style.hoverFillFor(root.contentForeground, Color.accent)
                : "transparent"
              z: gripArea.drag.active ? 2 : 0

              RowLayout {
                id: workspaceRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(4)

                Item {
                  Layout.preferredWidth: Style.space(22)
                  Layout.preferredHeight: Style.space(28)

                  Text {
                    anchors.centerIn: parent
                    text: "󰇈"
                    color: root.dim
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.icon
                  }

                  MouseArea {
                    id: gripArea
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    drag.target: workspaceCard
                    drag.axis: Drag.YAxis
                    onPressed: {
                      scroller.interactive = false
                      root.selectWorkspace(workspaceCard.modelData.id)
                    }
                    onReleased: {
                      scroller.interactive = true
                      root.finishDrag(workspaceCard.modelData.id, workspaceCard.y, workspaceCard.height)
                      workspaceCard.y = 0
                    }
                  }
                }

                WidgetButton {
                  bar: root.bar
                  text: modelData.name
                  tooltipText: "Select " + modelData.name
                  onPressed: function() { root.selectWorkspace(modelData.id) }
                }

                NumberField {
                  id: workspaceNumber
                  label: ""
                  value: modelData.workspace
                  from: 1
                  to: 10
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  fieldWidth: Style.space(56)
                  onModified: function(value) {
                    if (service) service.setWorkspaceNumber(modelData.id, value)
                  }
                  Connections {
                    target: workspaceNumber.field
                    function onActiveFocusChanged() { root.editingNumber = workspaceNumber.field.activeFocus }
                  }
                }

                Item { Layout.fillWidth: true }

                PanelActionButton {
                  iconText: "󰁝"
                  tooltipText: "Move up"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: moveWorkspace(modelData.id, -1)
                }

                PanelActionButton {
                  iconText: "󰁅"
                  tooltipText: "Move down"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: moveWorkspace(modelData.id, 1)
                }

                PanelActionButton {
                  iconText: "󰁔"
                  tooltipText: "Go to workspace"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: goToWorkspace(modelData.workspace)
                }

                PanelActionButton {
                  iconText: "󰐊"
                  tooltipText: "Launch assigned apps"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: launchSelectedWorkspace(modelData.id)
                }

                PanelActionButton {
                  iconText: "󰆴"
                  tooltipText: "Remove workspace"
                  foreground: root.contentForeground
                  hoverColor: root.bar ? root.bar.urgent : Color.urgent
                  fontFamily: root.contentFontFamily
                  onClicked: deleteWorkspace(modelData.id)
                }
              }

              MouseArea {
                z: -1
                anchors.fill: parent
                onClicked: root.selectWorkspace(modelData.id)
              }
            }
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: newWorkspaceField
              Layout.fillWidth: true
              text: root.newWorkspaceName
              placeholderText: "New workspace name"
              foreground: root.contentForeground
              font.family: root.contentFontFamily
              onTextChanged: root.newWorkspaceName = text
              onAccepted: root.addNamedWorkspace()
            }

            PanelActionButton {
              iconText: "󰐕"
              tooltipText: "Add workspace"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.addNamedWorkspace()
            }
          }

          PanelSeparator { width: parent.width; foreground: root.contentForeground }

          TextField {
            id: renameField
            visible: selected !== null
            width: parent.width
            text: root.selectedName
            placeholderText: "Workspace name"
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            onTextChanged: root.selectedName = text
            onEditingFinished: root.commitSelectedName()
            onAccepted: root.commitSelectedName()
          }

          PanelSectionHeader {
            width: parent.width
            text: selected ? selected.name + " apps" : "Apps"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          Text {
            visible: !selected || selected.apps.length === 0
            width: parent.width
            text: selected ? "No apps assigned yet." : "Select a workspace."
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: selected ? selected.apps : []

            RowLayout {
              required property var modelData
              width: content.width
              spacing: Style.space(6)

              Text {
                Layout.fillWidth: true
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Text {
                text: modelData.class || modelData.desktopId
                color: root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              PanelActionButton {
                iconText: "󰆴"
                tooltipText: "Remove app"
                foreground: root.contentForeground
                hoverColor: root.bar ? root.bar.urgent : Color.urgent
                fontFamily: root.contentFontFamily
                onClicked: if (service && selected) service.removeApp(selected.id, modelData.id)
              }
            }
          }

          SearchableDropdown {
            id: appPicker
            width: parent.width
            label: "Add installed app"
            placeholderText: "Search apps"
            emptyText: "No matching apps"
            options: root.appOptions
            value: root.pendingAppId
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) {
              root.pendingAppId = value
              if (!service || !selected) return
              for (var i = 0; i < root.appOptions.length; i++) {
                if (root.appOptions[i].value === value) {
                  service.addApp(selected.id, root.appOptions[i].app)
                  root.pendingAppId = ""
                  appPicker.value = ""
                  break
                }
              }
            }
          }

          Button {
            width: parent.width
            text: "Assign focused window"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: {
              if (service && selected) service.assignActiveWindow(selected.id)
            }
          }

          Button {
            width: parent.width
            text: "Assign open windows"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: {
              if (!service) return
              service.refreshWindows()
              Qt.callLater(function() { service.importOpenWindows() })
            }
          }

          Text {
            width: parent.width
            text: "Open-window import parks each unique app on the workspace it is on now. Apps already spread across workspaces, like terminals, are skipped."
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            visible: service && service.lastError !== ""
            width: parent.width
            text: service ? service.lastError : ""
            color: root.bar ? root.bar.urgent : Color.urgent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
