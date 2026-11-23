import QtQuick
import Pinna

// Kutu açılınca ya da bağlanınca köşede beliren bildirim kartı. Gölge ve konum pencere yöneticisinden gelir.
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
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
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
                text: win.connecting ? qsTr("Bağlanıyor…") : win.connected ? qsTr("Bağlı") : qsTr("Kutu açık, bağlanmaya hazır")
                font: Theme.footnote
                color: Theme.text2
            }
        }

        Row {
            x: 122
            y: 58
            spacing: 14
            Repeater {
                model: [["left", qsTr("Sol")], ["right", qsTr("Sağ")], ["case", qsTr("Kutu")]]
                Row {
                    required property var modelData
                    visible: win.level(modelData[0]) !== null
                    spacing: 5
                    BatteryRing {
                        size: 22
                        stroke: 2.4
                        level: win.level(parent.modelData[0])
                        charging: !!(win.bat[parent.modelData[0]] || {}).charging
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[1] + " " + win.level(parent.modelData[0]) + "%"
                        font: Theme.footnote
                        color: Theme.text
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            spacing: 8
            Button {
                text: qsTr("Ayarlar")
                onClicked: { Backend.openSettings(); Qt.quit() }
            }
            Button {
                visible: !win.connected
                primary: true
                busy: win.connecting
                text: qsTr("Bağlan")
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
