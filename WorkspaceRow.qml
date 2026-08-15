import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: rowRoot

  property var workspace: ({})
  property bool selected: false
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  property var bar: null

  signal selectRequested()
  signal moveRequested(int delta)
  signal dragStarted()
  signal dragFinished(real offsetY, real rowHeight)
  signal goRequested()
  signal launchRequested()
  signal deleteRequested()
  signal numberChanged(int value)
  signal numberFocusChanged(bool on)

  width: parent ? parent.width : Style.space(320)
  height: row.implicitHeight + Style.space(10)
  radius: Style.cornerRadius
  color: selected ? Style.hoverFillFor(foreground, Color.accent) : "transparent"
  z: gripArea.drag.active ? 2 : 0

  RowLayout {
    id: row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(4)
    anchors.rightMargin: Style.space(4)
    spacing: Style.space(6)

    Rectangle {
      id: grip
      Layout.minimumWidth: Style.space(32)
      Layout.preferredWidth: Style.space(32)
      Layout.maximumWidth: Style.space(32)
      Layout.preferredHeight: Style.space(32)
      radius: Style.cornerRadius
      color: gripArea.containsMouse || gripArea.drag.active
        ? Style.hoverFillFor(rowRoot.foreground, Color.accent)
        : Qt.rgba(rowRoot.foreground.r, rowRoot.foreground.g, rowRoot.foreground.b, 0.08)

      Text {
        anchors.centerIn: parent
        text: "≡"
        color: rowRoot.foreground
        font.family: rowRoot.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      MouseArea {
        id: gripArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        drag.target: rowRoot
        drag.axis: Drag.YAxis
        onPressed: {
          rowRoot.selectRequested()
          rowRoot.dragStarted()
        }
        onReleased: {
          rowRoot.dragFinished(rowRoot.y, rowRoot.height)
          rowRoot.y = 0
        }
      }
    }

    PanelActionButton {
      iconText: "▲"
      tooltipText: "Move up"
      foreground: rowRoot.foreground
      fontFamily: rowRoot.fontFamily
      onClicked: rowRoot.moveRequested(-1)
    }

    PanelActionButton {
      iconText: "▼"
      tooltipText: "Move down"
      foreground: rowRoot.foreground
      fontFamily: rowRoot.fontFamily
      onClicked: rowRoot.moveRequested(1)
    }

    Text {
      Layout.fillWidth: true
      text: workspace && workspace.name ? workspace.name : ""
      color: rowRoot.foreground
      font.family: rowRoot.fontFamily
      font.pixelSize: Style.font.body
      font.bold: rowRoot.selected
      elide: Text.ElideRight

      MouseArea {
        anchors.fill: parent
        onClicked: rowRoot.selectRequested()
      }
    }

    NumberField {
      id: workspaceNumber
      label: ""
      value: workspace && workspace.workspace ? workspace.workspace : 1
      from: 1
      to: 10
      foreground: rowRoot.foreground
      fontFamily: rowRoot.fontFamily
      fieldWidth: Style.space(56)
      onModified: function(value) { rowRoot.numberChanged(value) }
      Connections {
        target: workspaceNumber.field
        function onActiveFocusChanged() { rowRoot.numberFocusChanged(workspaceNumber.field.activeFocus) }
      }
    }

    PanelActionButton {
      iconText: "→"
      tooltipText: "Go to workspace"
      foreground: rowRoot.foreground
      fontFamily: rowRoot.fontFamily
      onClicked: rowRoot.goRequested()
    }

    PanelActionButton {
      iconText: "×"
      tooltipText: "Remove workspace"
      foreground: rowRoot.foreground
      hoverColor: rowRoot.bar && rowRoot.bar.urgent ? rowRoot.bar.urgent : Color.urgent
      fontFamily: rowRoot.fontFamily
      onClicked: rowRoot.deleteRequested()
    }
  }
}
