import QtQuick
import Pinna

// Options side by side; arrow keys work too.
Rectangle {
    id: root
    property var options: []
    property int current: 0
    signal picked(int index)
    function pick(i) { if (enabled && i !== current && i >= 0 && i < options.length) picked(i) }

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 28
    radius: Theme.small
    color: Theme.control
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onLeftPressed: pick(current - 1)
    Keys.onRightPressed: pick(current + 1)
    FocusRing {}

    Row {
        id: row
        x: 2
        y: 2
        Repeater {
            model: root.options
            Rectangle {
                id: seg
                required property int index
                required property string modelData
                readonly property bool on: index === root.current
                width: Math.max(56, label.implicitWidth + 20)
                height: root.height - 4
                radius: Theme.small - 2
                color: on ? Theme.card : area.containsMouse ? Theme.hover : "transparent"
                border.width: on && !Theme.dark ? 1 : 0
                border.color: Theme.border
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: seg.modelData
                    font.family: Theme.family
                    font.pixelSize: 12
                    font.weight: seg.on ? 600 : 400
                    color: seg.on ? Theme.text : Theme.text2
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.pick(seg.index)
                }
            }
        }
    }
}
