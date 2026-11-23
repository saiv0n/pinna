import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

C.TextField {
    id: root
    implicitWidth: 200
    implicitHeight: 28
    font: Theme.body
    color: Theme.text
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText
    placeholderTextColor: Theme.text3
    leftPadding: 8
    rightPadding: 8
    verticalAlignment: Text.AlignVCenter
    background: Rectangle {
        radius: Theme.small
        color: Theme.bg
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.focus : Theme.border
    }
}
