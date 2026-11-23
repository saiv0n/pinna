import QtQuick
import Pinna

// In window confirmation dialog. Dims the background, Esc closes it.
Rectangle {
    id: root
    property string title
    property string text
    property string code
    property string accept: qsTr("Continue")
    property var onAccepted: null
    function ask(t, body, cmd, label, fn) {
        title = t; text = body; code = cmd || ""; accept = label || qsTr("Continue"); onAccepted = fn
        visible = true
        ok.forceActiveFocus()
    }
    anchors.fill: parent
    color: Theme.shade
    visible: false
    z: 90
    MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    Keys.onEscapePressed: visible = false

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - 48)
        height: col.implicitHeight + 40
        radius: 12
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        MouseArea { anchors.fill: parent }
        Column {
            id: col
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 12
            Text { text: root.title; font: Theme.label; color: Theme.text; width: parent.width; wrapMode: Text.Wrap }
            Text { text: root.text; font: Theme.body; color: Theme.text2; width: parent.width; wrapMode: Text.Wrap }
            Rectangle {
                visible: !!root.code
                width: parent.width
                height: cmd.implicitHeight + 16
                radius: 6
                color: Theme.bg
                border.width: 1
                border.color: Theme.border
                TextEdit {
                    id: cmd
                    x: 8
                    y: 8
                    width: parent.width - 16
                    text: root.code
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Theme.text
                    selectionColor: Theme.accent
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Button { text: qsTr("Cancel"); onClicked: root.visible = false }
                Button {
                    id: ok
                    primary: true
                    text: root.accept
                    onClicked: { root.visible = false; if (root.onAccepted) root.onAccepted() }
                }
            }
        }
    }
}
