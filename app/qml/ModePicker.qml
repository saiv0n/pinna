import QtQuick
import Pinna

// The four listening modes side by side. The choice changes right away in Backend.
Row {
    id: root
    property string mode: Store.s.mode || ""
    readonly property var modes: ["off", "transparency", "adaptive", "anc"]
    readonly property bool allowOff: Store.setting("allowOff", true)
    readonly property var shown: allowOff || mode === "off" ? modes : modes.slice(1)
    readonly property int index: shown.indexOf(mode)

    function pick(i) {
        if (!enabled || i < 0 || i >= shown.length || i === index) return
        Backend.setMode(shown[i])
    }

    spacing: 8
    activeFocusOnTab: true
    Keys.onLeftPressed: pick(index - 1)
    Keys.onRightPressed: pick(index + 1)
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.RadioButton
    Accessible.name: Store.modeNames[mode] || ""

    Repeater {
        model: root.modes
        Rectangle {
            id: tile
            required property string modelData
            readonly property bool on: modelData === root.mode
            visible: root.shown.indexOf(modelData) >= 0
            width: (root.width - root.spacing * (root.shown.length - 1)) / root.shown.length
            height: 72
            radius: Theme.radius
            color: on ? Theme.accent : area.containsMouse ? Theme.controlHover : Theme.control
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 2
                border.color: Theme.focus
                visible: root.activeFocus && tile.on
            }
            ModeIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 11
                mode: tile.modelData
                color: tile.on ? Theme.accentText : Theme.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 46
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Store.modeNames[tile.modelData]
                font.family: Theme.family
                font.pixelSize: 12
                font.weight: tile.on ? 600 : 500
                color: tile.on ? Theme.accentText : Theme.text
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.pick(root.shown.indexOf(tile.modelData))
            }
        }
    }
}
