import QtQuick
import Pinna

// Dinleme modu seçici: her mod gri bir dairede, seçilenin altında yaylı kayan mavi daire.
Item {
    id: root
    property string mode
    property bool allowOff: true
    signal picked(string mode)

    readonly property var modes: ["off", "transparency", "adaptive", "anc"]
        .filter(k => allowOff || k !== "off" || mode === "off")

    // tıklanınca daire hemen kayar; servis reddederse geri döner
    property string shown: mode
    onModeChanged: shown = mode
    Connections {
        target: Backend
        function onError() { root.shown = root.mode }
    }
    function pick(k) {
        if (k === shown || !enabled) return
        shown = k
        picked(k)
    }

    readonly property int index: modes.indexOf(shown)
    readonly property real cell: width / modes.length
    readonly property real dot: 48

    width: parent ? parent.width : 0
    height: 98
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onLeftPressed: if (index > 0) pick(modes[index - 1])
    Keys.onRightPressed: if (index < modes.length - 1) pick(modes[index + 1])

    Rectangle {
        id: knob
        visible: root.index >= 0
        y: 8
        width: root.dot
        height: root.dot
        radius: width / 2
        color: Theme.accent
        x: Math.max(0, root.index) * root.cell + (root.cell - width) / 2
        scale: cells.pressedIndex === root.index ? 0.92 : 1
        border.width: root.activeFocus ? 3 : 0
        border.color: Theme.focus
        Behavior on x { enabled: !Theme.reduce; SpringAnimation { spring: Theme.springK; damping: Theme.springD; epsilon: 0.2 } }
        Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.005 } }
    }

    Item {
        id: cells
        anchors.fill: parent
        property int pressedIndex: -1

        Repeater {
            model: root.modes
            Item {
                id: cell
                required property int index
                required property string modelData
                readonly property bool selected: index === root.index
                x: index * root.cell
                width: root.cell
                height: root.height

                Rectangle {
                    x: cell.x + (cell.width - width) / 2
                    y: 8
                    width: root.dot
                    height: root.dot
                    radius: width / 2
                    color: Theme.fill
                    z: -1
                    parent: root
                    scale: cells.pressedIndex === cell.index && !cell.selected ? 0.92 : 1
                    Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.005 } }
                }

                ModeIcon {
                    x: (parent.width - width) / 2
                    y: 8 + (root.dot - height) / 2
                    mode: cell.modelData
                    color: cell.selected ? Theme.accentText : Theme.text
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                Text {
                    y: 8 + root.dot + 7
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Store.modeNames[cell.modelData].replace(" ", "\n")
                    font.pixelSize: 12
                    font.weight: cell.selected ? 600 : 400
                    font.letterSpacing: -0.1
                    color: cell.selected ? Theme.text : Theme.text2
                    lineHeight: 0.95
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: cells.pressedIndex = pressed ? cell.index : -1
                    onClicked: root.pick(cell.modelData)
                }
            }
        }
    }
}
