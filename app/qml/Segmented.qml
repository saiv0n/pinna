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
    property string label
    Accessible.role: Accessible.PageTabList
    Accessible.name: label
    Accessible.description: options[current] || ""
    Keys.onLeftPressed: pick(current - 1)
    Keys.onRightPressed: pick(current + 1)
    FocusRing {}

    // the selected segment is a card that slides between options
    Rectangle {
        id: thumb
        readonly property Item at: segs.count > root.current && root.current >= 0 ? segs.itemAt(root.current) : null
        visible: !!at
        x: at ? row.x + at.x : 0
        y: row.y
        width: at ? at.width : 0
        height: root.height - 4
        radius: Theme.small - 2
        color: Theme.card
        border.width: Theme.dark ? 0 : 1
        border.color: Theme.border
        Behavior on x { enabled: !Theme.reduce && thumb.visible; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: !Theme.reduce && thumb.visible; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    Row {
        id: row
        x: 2
        y: 2
        Repeater {
            id: segs
            model: root.options
            Rectangle {
                id: seg
                required property int index
                required property string modelData
                readonly property bool on: index === root.current
                width: Math.max(56, label.implicitWidth + 20)
                height: root.height - 4
                radius: Theme.small - 2
                color: !on && area.containsMouse ? Theme.hover : Qt.alpha(Theme.hover, 0)
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: seg.modelData
                    font.family: Theme.family
                    font.pixelSize: 12
                    font.weight: seg.on ? 600 : 400
                    color: seg.on ? Theme.text : Theme.text2
                    Behavior on color { enabled: !Theme.reduce; ColorAnimation { duration: 160 } }
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
