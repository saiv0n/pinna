import QtQuick
import Pinna

// The four listening modes side by side. A pill slides between them: grey tiles at the
// bottom, the pill above them, icons and labels on top.
Item {
    id: root
    property string mode: Store.s.mode || ""
    readonly property var modes: ["off", "transparency", "adaptive", "anc"]
    readonly property bool allowOff: Store.setting("allowOff", true)
    readonly property var shown: modes.filter(m => (m !== "off" || allowOff || mode === "off") && (m !== "adaptive" || Store.adaptive))
    readonly property int index: shown.indexOf(mode)
    readonly property real spacing: 8
    readonly property real tileWidth: (width - spacing * (shown.length - 1)) / shown.length
    property int hovered: -1
    property int pressed: -1

    function pick(i) {
        if (!enabled || i < 0 || i >= shown.length || i === index) return
        Backend.setMode(shown[i])
    }
    function tileX(i) { return i * (tileWidth + spacing) }
    property int lastIndex: -1
    onIndexChanged: {
        if (lastIndex >= 0 && index >= 0 && !Theme.reduce && width > 0) {
            pill.offset = tileX(lastIndex) - tileX(index) + pill.offset
            slide.restart()
        }
        lastIndex = index
    }
    Component.onCompleted: lastIndex = index

    implicitHeight: 72
    activeFocusOnTab: true
    Keys.onLeftPressed: pick(index - 1)
    Keys.onRightPressed: pick(index + 1)
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.RadioButton
    Accessible.name: Store.modeNames[mode] || ""

    Repeater {
        model: root.shown
        Rectangle {
            required property int index
            x: root.tileX(index)
            width: root.tileWidth
            height: root.height
            radius: Theme.radius
            color: root.hovered === index && index !== root.index ? Theme.controlHover : Theme.control
            scale: root.pressed === index ? 0.96 : 1
            Behavior on scale { enabled: !Theme.reduce; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { enabled: !Theme.reduce; ColorAnimation { duration: 120 } }
        }
    }

    Rectangle {
        id: pill
        visible: root.index >= 0
        // only a mode change moves it; layout and resizes jump straight to place
        property real offset: 0
        x: root.tileX(Math.max(0, root.index)) + offset
        width: root.tileWidth
        height: root.height
        radius: Theme.radius
        color: Theme.accent
        scale: root.pressed === root.index ? 0.96 : 1
        NumberAnimation { id: slide; target: pill; property: "offset"; to: 0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        Behavior on scale { enabled: !Theme.reduce; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.focus
            visible: root.activeFocus
        }
    }

    Repeater {
        model: root.shown
        Item {
            id: tile
            required property int index
            required property string modelData
            readonly property bool on: index === root.index
            x: root.tileX(index)
            width: root.tileWidth
            height: root.height
            ModeIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 11
                mode: tile.modelData
                color: tile.on ? Theme.accentText : Theme.text
                Behavior on color { enabled: !Theme.reduce; ColorAnimation { duration: 180 } }
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
                Behavior on color { enabled: !Theme.reduce; ColorAnimation { duration: 180 } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: root.hovered = containsMouse ? tile.index : (root.hovered === tile.index ? -1 : root.hovered)
                onPressedChanged: root.pressed = pressed ? tile.index : -1
                onClicked: root.pick(tile.index)
            }
        }
    }
}
