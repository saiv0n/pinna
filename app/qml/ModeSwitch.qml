import QtQuick
import Earshot

// Dört dinleme modu. Seçili modun arkasındaki dolgu kayarak yer değiştirir.
Rectangle {
    id: root
    property string mode
    property bool allowOff: true
    signal picked(string mode)

    readonly property var modes: [
        { key: "off", label: "Kapalı" },
        { key: "anc", label: "Gürültü\nEngelleme" },
        { key: "adaptive", label: "Uyarlanabilir" },
        { key: "transparency", label: "Şeffaf" }
    ]
    readonly property int index: modes.findIndex(m => m.key === mode)
    readonly property real cell: (width - 16) / modes.length

    width: parent ? parent.width : 0
    height: 104
    radius: Theme.radius
    color: Theme.group
    activeFocusOnTab: true
    Keys.onLeftPressed: if (index > 0) picked(modes[index - 1].key)
    Keys.onRightPressed: if (index < modes.length - 1) picked(modes[index + 1].key)

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
    }

    Rectangle {
        id: pill
        visible: root.index >= 0
        width: 48
        height: 48
        radius: 24
        y: 12
        x: 8 + root.index * root.cell + (root.cell - width) / 2
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: root.modes
        Item {
            id: cellItem
            required property int index
            required property var modelData
            readonly property bool selected: index === root.index
            x: 8 + index * root.cell
            width: root.cell
            height: root.height

            Rectangle {
                width: 48
                height: 48
                radius: 24
                y: 12
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.segment
                opacity: cellItem.selected ? 0 : (hover.containsMouse ? 1 : 0.7)
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }

            ModeIcon {
                y: 12 + (48 - height) / 2
                anchors.horizontalCenter: parent.horizontalCenter
                mode: cellItem.modelData.key
                color: cellItem.selected ? Theme.accentText : Theme.text
                Behavior on color { ColorAnimation { duration: Theme.medium } }
            }

            Text {
                y: 66
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: cellItem.modelData.label
                font.pixelSize: 12
                font.weight: cellItem.selected ? 600 : 450
                color: cellItem.selected ? Theme.text : Theme.text2
                lineHeight: 0.95
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!cellItem.selected) root.picked(cellItem.modelData.key)
            }
        }
    }
}
