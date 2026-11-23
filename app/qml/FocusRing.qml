import QtQuick
import Pinna

// Klavyeyle gelinen öğenin çevresinde halka.
Rectangle {
    property Item target: parent
    property real r: Theme.small
    anchors.fill: parent
    anchors.margins: -3
    radius: r + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.focus
    visible: target && target.activeFocus
}
