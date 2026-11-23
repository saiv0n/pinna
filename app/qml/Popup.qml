import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Pinna

// Kutu açılınca ya da bağlanınca alttan yaylanarak çıkan kart.
Window {
    id: win
    width: 400
    height: 410
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: true
    title: "Pinna"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    readonly property var s: Backend.state
    readonly property var bat: s.battery || ({})
    readonly property bool connected: !!s.connected
    readonly property bool anyBattery: ["left", "right", "case"].some(k => bat[k] && bat[k].level !== null && bat[k].level !== undefined)
    property bool connecting: false
    property bool leaving: false

    function cell(k) { return bat[k] || ({}) }
    function leave() {
        if (leaving) return
        leaving = true
        out.start()
    }

    Timer {
        id: idle
        interval: 9000
        running: !hover.hovered && !win.connecting && !win.leaving
        onTriggered: win.leave()
    }
    Shortcut { sequence: "Escape"; onActivated: win.leave() }

    Connections {
        target: Backend
        function onStateChanged() {
            if (win.connecting && Backend.state.connected) {
                win.connecting = false
                idle.interval = 3500
                idle.restart()
            }
        }
        function onError() { win.connecting = false }
    }

    Item {
        id: card
        x: 12
        width: parent.width - 24
        height: parent.height - 24
        // ekranın altından yaylanarak gelir
        property real offset: Theme.reduce ? 0 : win.height
        y: 12 + offset
        opacity: Theme.reduce ? 0 : 1
        Component.onCompleted: { offset = 0; opacity = 1 }
        Behavior on offset { enabled: !win.leaving; SpringAnimation { spring: 2.6; damping: 0.34; epsilon: 0.4 } }
        Behavior on opacity { enabled: !win.leaving; NumberAnimation { duration: 200 } }

        ParallelAnimation {
            id: out
            NumberAnimation { target: card; property: "offset"; to: Theme.reduce ? 0 : win.height; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 280; easing.type: Easing.InQuad }
            onFinished: Qt.quit()
        }

        HoverHandler { id: hover }

        RectangularShadow {
            anchors.fill: bg
            offset.y: 8
            radius: bg.radius
            blur: 28
            color: Theme.dark ? "#b0000000" : "#30000000"
        }
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 34
            color: Theme.group
            border.width: Theme.dark ? 1 : 0
            border.color: "#2c2c2e"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            text: win.s.name || "AirPods"
            font.pixelSize: 19
            font.weight: 650
            color: Theme.text
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            width: 30
            height: 30
            radius: 15
            color: closeArea.pressed ? Theme.groupPress : Theme.fill
            Shape {
                anchors.centerIn: parent
                width: 10
                height: 10
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.text2
                    strokeWidth: 2
                    capStyle: ShapePath.RoundCap
                    startX: 1; startY: 1
                    PathLine { x: 9; y: 9 }
                    PathMove { x: 9; y: 1 }
                    PathLine { x: 1; y: 9 }
                }
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: win.leave()
            }
        }

        // kutudan çıkıyormuş gibi: aşağıdan yükselip iki yana açılırlar
        Item {
            id: art
            width: parent.width
            height: 150
            y: 62

            Rectangle {
                id: floor
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 14
                width: 190
                height: 16
                radius: 8
                color: Theme.dark ? "#000000" : "#2a000000"
                visible: false
            }
            MultiEffect {
                source: floor
                anchors.fill: floor
                anchors.margins: -24
                blurEnabled: true
                blur: 1
                blurMax: 24
                opacity: Theme.dark ? 0.6 : 0.5
                autoPaddingEnabled: true
            }

            Repeater {
                model: [-1, 1]
                Image {
                    id: bud
                    required property int modelData
                    required property int index
                    property real rise: Theme.reduce ? 1 : 0
                    source: "../assets/bud.png"
                    mirror: modelData > 0
                    width: 104
                    height: 140
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    x: art.width / 2 + (modelData < 0 ? -width - 2 : 2) + modelData * (1 - rise) * -18
                    y: (1 - rise) * 46 + 4
                    rotation: modelData * (1 - rise) * 10
                    opacity: Math.min(1, rise * 1.6)
                    scale: 0.86 + 0.14 * rise
                    Behavior on rise { SpringAnimation { spring: 2.4; damping: 0.3; epsilon: 0.002 } }
                    Timer { interval: 160 + bud.index * 70; running: true; onTriggered: bud.rise = 1 }
                }
            }
        }

        Row {
            id: rings
            visible: win.anyBattery
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.y + art.height + 14
            spacing: 28

            BatteryRing {
                level: win.cell("left").level === undefined ? null : win.cell("left").level
                charging: !!win.cell("left").charging
                delay: 250
                Image {
                    anchors.centerIn: parent
                    source: "../assets/bud.png"
                    height: 30
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
            BatteryRing {
                level: win.cell("right").level === undefined ? null : win.cell("right").level
                charging: !!win.cell("right").charging
                delay: 330
                Image {
                    anchors.centerIn: parent
                    source: "../assets/bud.png"
                    mirror: true
                    height: 30
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
            BatteryRing {
                visible: win.cell("case").level !== null && win.cell("case").level !== undefined
                level: win.cell("case").level === undefined ? null : win.cell("case").level
                charging: !!win.cell("case").charging
                delay: 410
                // kutu: kapaklı yuvarlak gövde
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 21
                    radius: 7
                    color: Theme.dark ? "#e8e8ed" : "#ffffff"
                    border.width: 1
                    border.color: Theme.dark ? "#00000000" : "#d1d1d6"
                    Rectangle { y: 6; width: parent.width; height: 1; color: Theme.dark ? "#8e8e93" : "#c7c7cc" }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 2.5; height: 2.5; radius: 1.25; color: Theme.green }
                }
            }
        }

        Text {
            visible: !win.anyBattery
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.y + art.height + 34
            text: win.connected ? "Bağlı" : "Bağlanmaya hazır"
            font: Theme.footnote
            color: Theme.text2
        }

        PillButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            width: parent.width - 40
            primary: !win.connected
            busy: win.connecting
            text: win.connecting ? "Bağlanıyor…" : win.connected ? "Ayarları Aç" : "Bağlan"
            onClicked: {
                if (win.connected) {
                    Backend.openSettings()
                    win.leave()
                } else {
                    win.connecting = true
                    Backend.connectDevice()
                }
            }
        }
    }
}
