import QtQuick
import Pinna

Rectangle {
    id: root
    property string text
    property bool primary: false
    property bool destructive: false
    property bool busy: false
    signal clicked()

    function go() { if (enabled && !busy) clicked() }

    implicitWidth: Math.max(64, row.implicitWidth + 24)
    implicitHeight: 28
    radius: Theme.small
    color: primary ? (area.pressed ? Qt.darker(Theme.accent, 1.15) : area.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                   : (area.pressed ? Theme.press : area.containsMouse ? Theme.controlHover : Theme.control)
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onReturnPressed: go()
    Keys.onEnterPressed: go()
    Keys.onSpacePressed: go()
    Accessible.role: Accessible.Button
    Accessible.name: text

    FocusRing {}
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Spinner { visible: root.busy; size: 12; color: label.color; anchors.verticalCenter: parent.verticalCenter }
        Text {
            id: label
            text: root.text
            font: Theme.body
            color: root.primary ? Theme.accentText : root.destructive ? Theme.red : Theme.text
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.go()
    }
}
