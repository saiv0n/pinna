import QtQuick
import Pinna

// iOS'taki gürültü kontrolü seçicisi: gri zemin, seçilenin altında kayan beyaz karo.
Item {
    id: root
    property string mode
    property bool allowOff: true
    signal picked(string mode)

    readonly property var modes: ["off", "transparency", "adaptive", "anc"]
        .filter(k => allowOff || k !== "off" || mode === "off")

    // tıklanınca karo hemen kayar; servis reddederse geri döner
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
    readonly property real cell: (width - 4) / modes.length

    width: parent ? parent.width : 0
    height: 88
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onLeftPressed: if (index > 0) pick(modes[index - 1])
    Keys.onRightPressed: if (index < modes.length - 1) pick(modes[index + 1])

    Rectangle {
        anchors.fill: parent
        radius: 11
        color: Theme.segment
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
    }

    Rectangle {
        id: tile
        visible: root.index >= 0
        y: 2
        width: root.cell
        height: root.height - 4
        radius: 9
        color: Theme.thumb
        x: 2 + Math.max(0, root.index) * root.cell
        // basılı tutulan hücre seçiliyse karo hafifçe içe çöker
        scale: cells.pressedIndex === root.index ? 0.95 : 1
        Behavior on x { enabled: !Theme.reduce; SpringAnimation { spring: Theme.springK; damping: Theme.springD; epsilon: 0.25 } }
        Behavior on width { enabled: !Theme.reduce; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.005 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.bottomMargin: -1.5
            z: -1
            radius: parent.radius
            color: Theme.dark ? "#40000000" : "#1a000000"
        }
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
                x: 2 + index * root.cell
                width: root.cell
                height: root.height

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    opacity: area.pressed && !cell.selected ? 0.5 : 1
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    ModeIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        mode: cell.modelData
                        color: cell.selected ? Theme.text : Theme.text2
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Text {
                        width: cell.width - 8
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: Store.modeNames[cell.modelData].replace(" ", "\n")
                        font.pixelSize: 12
                        font.weight: cell.selected ? 600 : 450
                        color: cell.selected ? Theme.text : Theme.text2
                        lineHeight: 0.95
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: cells.pressedIndex = pressed ? cell.index : -1
                    onClicked: root.pick(cell.modelData)
                }
            }
        }
    }
}
