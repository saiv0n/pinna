import QtQuick
import QtQuick.Effects
import Pinna

// Kutu açılınca ya da bağlanınca beliren küçük kart.
Window {
    id: win
    width: 380
    height: 350
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
    property bool connecting: false
    property bool leaving: false

    function leave() {
        if (leaving) return
        leaving = true
        card.opacity = 0
        card.offset = 14
        quitTimer.start()
    }

    Timer { id: quitTimer; interval: 180; onTriggered: Qt.quit() }
    Timer {
        id: idle
        interval: 9000
        running: !hover.hovered && !win.connecting
        onTriggered: win.leave()
    }
    Shortcut { sequence: "Escape"; onActivated: win.leave() }

    Connections {
        target: Backend
        function onStateChanged() {
            if (win.connecting && Backend.state.connected) {
                win.connecting = false
                idle.interval = 3000
                idle.restart()
            }
        }
        function onError() { win.connecting = false }
    }

    Item {
        id: card
        property real offset: 18
        anchors.fill: parent
        anchors.margins: 14
        opacity: 0
        transform: Translate { y: card.offset }
        Component.onCompleted: { opacity = 1; offset = 0 }
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on offset { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover }

        RectangularShadow {
            anchors.fill: bg
            offset.y: 4
            radius: bg.radius
            blur: 18
            spread: 0
            color: Theme.dark ? "#99000000" : "#38000000"
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 22
            color: Theme.group
            border.width: 1
            border.color: Theme.separator
        }

        Text {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            text: win.s.name || "AirPods"
            font: Theme.label
            color: Theme.text
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            width: 26
            height: 26
            radius: 13
            color: closeArea.containsMouse ? Theme.groupPress : Theme.segment
            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 11
                color: Theme.text2
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.leave()
            }
        }

        Image {
            id: art
            source: "../assets/set.png"
            width: 200
            height: 131
            fillMode: Image.PreserveAspectFit
            mipmap: true
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46
        }

        Row {
            id: rings
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.y + art.height + 12
            spacing: 18
            BatteryRing {
                size: 46
                label: "Sol"
                level: win.bat.left ? win.bat.left.level : null
                charging: win.bat.left ? win.bat.left.charging : false
            }
            BatteryRing {
                size: 46
                label: "Sağ"
                level: win.bat.right ? win.bat.right.level : null
                charging: win.bat.right ? win.bat.right.charging : false
            }
            BatteryRing {
                size: 46
                label: "Kutu"
                level: win.bat["case"] ? win.bat["case"].level : null
                charging: win.bat["case"] ? win.bat["case"].charging : false
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: parent.width - 40
            height: 40
            radius: 20
            color: win.connected ? (btn.pressed ? Theme.groupPress : Theme.segment)
                 : (btn.pressed ? Qt.darker(Theme.accent, 1.12) : Theme.accent)
            opacity: win.connecting ? 0.65 : 1

            Text {
                anchors.centerIn: parent
                text: win.connecting ? "Bağlanıyor…" : win.connected ? "Ayarları Aç" : "Bağlan"
                font: Theme.label
                color: win.connected ? Theme.text : Theme.accentText
            }
            MouseArea {
                id: btn
                anchors.fill: parent
                enabled: !win.connecting
                cursorShape: Qt.PointingHandCursor
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
}
