import QtQuick
import Earshot

// Alttan beliren kısa hata mesajı.
Rectangle {
    id: root
    property string message
    function show(m) {
        message = m
        opacity = 1
        timer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 18 + (1 - opacity) * -8
    width: Math.min(parent.width - 32, msg.implicitWidth + 32)
    height: msg.implicitHeight + 20
    radius: 10
    color: Theme.dark ? "#2b2f36" : "#1d1f23"
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    Text {
        id: msg
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.parent.width - 64)
        text: root.message
        font: Theme.body
        color: "#f3f4f6"
        wrapMode: Text.WordWrap
    }

    Timer {
        id: timer
        interval: 4000
        onTriggered: root.opacity = 0
    }
}
