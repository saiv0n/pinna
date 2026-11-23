import QtQuick
import Earshot

// iOS tarzı anahtar. Tıklayınca hemen döner, gerçek değer servisten gelince yerine oturur.
Item {
    id: root
    property bool checked
    signal toggled(bool value)

    width: 46
    height: 28
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true

    Keys.onSpacePressed: flip()
    function flip() {
        if (!enabled) return
        checked = !checked
        toggled(checked)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.switchOn : Theme.track
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.focus
        visible: root.activeFocus
    }

    Rectangle {
        id: knob
        width: 24
        height: 24
        radius: 12
        y: 2
        x: root.checked ? root.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -0.5
            z: -1
            radius: width / 2
            color: "#28000000"
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip()
    }
}
