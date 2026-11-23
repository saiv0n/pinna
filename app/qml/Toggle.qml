import QtQuick
import Pinna

// iOS anahtarı. Basılıyken düğme uzar, bırakınca yayla yerine oturur.
Item {
    id: root
    property bool checked
    property bool pressed: false
    signal toggled(bool value)

    // tıklanınca hemen döner, servis reddederse eski hâline geri gelir
    property bool on: checked
    onCheckedChanged: on = checked
    Connections {
        target: Backend
        function onError() { root.on = root.checked }
    }

    width: 51
    height: 31
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onSpacePressed: flip()

    function flip() {
        if (!enabled) return
        on = !on
        toggled(on)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.track
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.green
        opacity: root.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
        readonly property real w: root.pressed || area.pressed ? 34 : 27
        width: w
        height: 27
        radius: 13.5
        y: 2
        x: root.on ? root.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x { enabled: !Theme.reduce; SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.2 } }
        Behavior on width { enabled: !Theme.reduce; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -0.5
            anchors.topMargin: 0.5
            anchors.bottomMargin: -1.5
            z: -1
            radius: height / 2
            color: "#24000000"
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip()
    }
}
