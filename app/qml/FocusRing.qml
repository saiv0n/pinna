import QtQuick
import Pinna

// A ring around the item reached by keyboard.
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
