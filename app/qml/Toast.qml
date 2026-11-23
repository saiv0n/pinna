import QtQuick
import Pinna

// Alt ortada kısa süreli mesaj. Hatalarda ne olduğunu, ne yapılacağını ve bir düğmeyi gösterir.
Rectangle {
    id: root
    property bool bad: false
    property var act: null
    function show(t, body, isError, label, fn) {
        title.text = t
        detail.text = body || ""
        bad = !!isError
        button.text = label || ""
        act = fn || null
        opacity = 1
        hide.interval = isError ? 8000 : 4000
        hide.restart()
    }
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    width: Math.min(parent.width - 40, 440)
    height: Math.max(48, texts.implicitHeight + 24)
    radius: 12
    color: Theme.card
    border.width: 1
    border.color: Theme.border
    opacity: 0
    visible: opacity > 0
    z: 100
    Behavior on opacity { NumberAnimation { duration: Theme.medium } }
    Timer { id: hide; running: !hover.hovered && root.opacity === 1; onTriggered: root.opacity = 0 }
    HoverHandler { id: hover }

    Rectangle {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: root.bad ? Theme.red : Theme.green
    }
    Column {
        id: texts
        x: 32
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - (button.visible ? button.width + 12 : 0) - 40
        spacing: 2
        Text { id: title; width: parent.width; font: Theme.label; color: Theme.text; wrapMode: Text.Wrap }
        Text { id: detail; visible: !!text; width: parent.width; font: Theme.footnote; color: Theme.text2; wrapMode: Text.Wrap }
    }
    Button {
        id: button
        visible: !!text
        anchors.right: close.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        onClicked: { root.opacity = 0; if (root.act) root.act() }
    }
    IconButton {
        id: close
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        icon: "close"
        Accessible.name: qsTr("Kapat")
        onClicked: root.opacity = 0
    }
}
