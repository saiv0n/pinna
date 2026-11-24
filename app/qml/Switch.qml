import QtQuick
import Pinna

// Desktop sized switch. No local state since Backend changes the value right away.
Item {
    id: root
    property bool checked
    signal toggled(bool value)

    function flip() { if (enabled) toggled(!checked) }

    implicitWidth: 34
    implicitHeight: 20
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()
    // filled in by Setting from the row title
    property string label
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : area.containsMouse ? Theme.controlHover : Theme.control
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    FocusRing { r: 10 }
    Rectangle {
        width: 16
        height: 16
        radius: 8
        y: 2
        x: root.checked ? root.width - width - 2 : 2
        color: "#ffffff"
        border.width: Theme.dark ? 0 : 1
        border.color: "#1f000000"
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip()
    }
}
