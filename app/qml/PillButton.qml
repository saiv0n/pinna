import QtQuick
import Pinna

// iOS'un büyük dolgulu düğmesi. Basınca hafifçe küçülür.
Rectangle {
    id: root
    property string text
    property bool primary: true
    property bool busy: false
    signal clicked()

    implicitWidth: 240
    implicitHeight: 50
    radius: 14
    color: primary ? Theme.accent : Theme.fill
    opacity: !enabled ? 0.5 : area.pressed ? 0.82 : 1
    scale: area.pressed ? 0.97 : 1
    activeFocusOnTab: true
    Keys.onReturnPressed: if (!busy) clicked()
    Keys.onSpacePressed: if (!busy) clicked()
    Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.002 } }
    Behavior on opacity { NumberAnimation { duration: area.pressed ? 0 : 200 } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: parent.radius + 3
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
    }

    Row {
        anchors.centerIn: parent
        spacing: 8
        Spinner {
            visible: root.busy
            size: 16
            color: root.primary ? Theme.accentText : Theme.text2
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font: Theme.label
            color: root.primary ? Theme.accentText : Theme.accent
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: !root.busy && root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
