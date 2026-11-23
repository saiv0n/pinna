import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

// Sağ tık menüsü.
C.Menu {
    id: root
    padding: 4
    background: Rectangle {
        implicitWidth: 180
        radius: 8
        color: Theme.card
        border.width: 1
        border.color: Theme.border
    }
    delegate: C.MenuItem {
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
            radius: 4
            color: item.highlighted ? Theme.accent : "transparent"
        }
    }
}
