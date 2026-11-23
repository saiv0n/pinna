import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

C.MenuItem {
    id: item
    implicitHeight: 26
    contentItem: Text {
        text: item.text
        font: Theme.body
        leftPadding: 6
        color: !item.enabled ? Theme.text3 : item.highlighted ? Theme.accentText : Theme.text
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        implicitWidth: 200
        radius: 4
        color: item.highlighted ? Theme.accent : "transparent"
    }
}
