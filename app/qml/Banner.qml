import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Pinna

// Üstten yaylanarak inen kısa hata mesajı.
Item {
    id: root
    property string message
    property bool shown: false
    function show(m) {
        message = m
        shown = true
        timer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - 32, row.implicitWidth + 36)
    height: row.implicitHeight + 24
    y: shown ? 10 : -height - 20
    opacity: shown ? 1 : 0
    visible: opacity > 0
    z: 100
    Behavior on y { enabled: !Theme.reduce; SpringAnimation { spring: 3.6; damping: 0.4; epsilon: 0.3 } }
    Behavior on opacity { NumberAnimation { duration: 180 } }

    RectangularShadow {
        anchors.fill: bg
        offset.y: 6
        radius: bg.radius
        blur: 24
        color: Theme.dark ? "#a0000000" : "#26000000"
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2 > 26 ? 18 : height / 2
        color: Theme.dark ? "#2c2c2e" : "#ffffff"
        border.width: Theme.dark ? 1 : 0
        border.color: "#3a3a3c"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 9
        Rectangle {
            width: 20
            height: 20
            radius: 10
            color: Theme.red
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { x: 9; y: 4.5; width: 2; height: 7; radius: 1; color: "#ffffff" }
            Rectangle { x: 9; y: 13.5; width: 2; height: 2; radius: 1; color: "#ffffff" }
        }
        Text {
            width: Math.min(implicitWidth, root.parent.width - 100)
            anchors.verticalCenter: parent.verticalCenter
            text: root.message
            font: Theme.footnote
            color: Theme.text
            wrapMode: Text.WordWrap
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
    }
    Timer {
        id: timer
        interval: 4500
        onTriggered: root.shown = false
    }
}
