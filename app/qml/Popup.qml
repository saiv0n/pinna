import QtQuick
import Pinna

// The card that pops up in a corner when the case opens or the buds connect. Shadow and position come from the window manager.
Window {
    id: win
    width: 380
    height: 132
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: true
    title: "Pinna"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"

    readonly property var s: Backend.state
    readonly property var bat: s.battery || ({})
    readonly property bool connected: !!s.connected
    property bool connecting: false

    function level(k) { const c = bat[k]; return c && c.level !== null && c.level !== undefined ? c.level : null }

    Timer {
        interval: win.connecting ? 15000 : 8000
        running: !hover.hovered
        onTriggered: Qt.quit()
    }
    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    // to show the last known value while the case is closed
    Component.onCompleted: Backend.loadHistory()
    Connections {
        target: Backend
        function onError() { win.connecting = false }
        function onStateChanged() { if (win.connecting && Backend.state.connected) win.connecting = false }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 14
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        // drops in from above with a small settle, like a system banner
        opacity: 0
        scale: 0.94
        transform: Translate { id: drop; y: -14 }
        Component.onCompleted: Theme.reduce ? (opacity = 1, scale = 1, drop.y = 0) : arrive.start()
        ParallelAnimation {
            id: arrive
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: drop; property: "y"; to: 0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        HoverHandler { id: hover }

        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: -6
            Repeater {
                model: [false, true]
                Image {
                    required property bool modelData
                    source: "../assets/bud.png"
                    mirror: modelData
                    height: 96
                    width: 52
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
        }

        Column {
            x: 122
            y: 16
            width: parent.width - x - 16
            spacing: 2
            Text {
                width: parent.width - 28
                text: win.s.name || "AirPods"
                font: Theme.label
                color: Theme.text
                elide: Text.ElideRight
            }
            Text {
                text: win.connecting ? qsTr("Connecting…")
                    : win.connected ? (Store.modeNames[win.s.mode] ? qsTr("Connected") + "  ·  " + Store.modeNames[win.s.mode] : qsTr("Connected"))
                    : qsTr("Case open, ready to connect")
                font: Theme.footnote
                color: Theme.text2
            }
        }

        Row {
            x: 122
            y: 56
            spacing: 12
            Repeater {
                model: [["left", qsTr("Left")], ["right", qsTr("Right")], ["case", qsTr("Case")]]
                BatteryTile {
                    required property var modelData
                    readonly property var now: win.level(modelData[0])
                    readonly property var last: modelData[0] === "case" && now === null ? Store.lastCase : null
                    width: 62
                    name: modelData[1]
                    level: now !== null ? now : last ? last.level : null
                    stale: now === null
                    charging: now !== null && !!(win.bat[modelData[0]] || {}).charging
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            spacing: 8
            Button {
                text: qsTr("Settings")
                onClicked: { Backend.openSettings(); Qt.quit() }
            }
            Button {
                visible: !win.connected
                primary: true
                busy: win.connecting
                text: qsTr("Connect")
                onClicked: { win.connecting = true; Backend.connectDevice() }
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            icon: "close"
            onClicked: Qt.quit()
        }
    }
}
