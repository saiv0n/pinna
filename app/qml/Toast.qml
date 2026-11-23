import QtQuick
import Pinna

// Alt ortada kısa süreli mesaj.
Rectangle {
    id: root
    property bool bad: false
    function show(m, isError) {
        label.text = m
        bad = !!isError
        opacity = 1
        hide.restart()
    }
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    width: Math.min(parent.width - 40, label.implicitWidth + 28)
    height: label.implicitHeight + 16
    radius: 8
    color: Theme.dark ? "#3a3a40" : "#2b2b30"
    border.width: 1
    border.color: bad ? Theme.red : "transparent"
    opacity: 0
    visible: opacity > 0
    z: 100
    Behavior on opacity { NumberAnimation { duration: Theme.medium } }
    Timer { id: hide; interval: 4500; onTriggered: root.opacity = 0 }
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.parent.width - 68)
        wrapMode: Text.Wrap
        font: Theme.body
        color: "#ffffff"
    }
    MouseArea { anchors.fill: parent; onClicked: root.opacity = 0 }
}
