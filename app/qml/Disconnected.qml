import QtQuick
import Pinna

// Kulaklık bağlı değilken ya da servis çalışmıyorken gösterilen tek eylemli ekran.
Column {
    id: root
    property var s: ({})
    property bool daemon: true
    property bool busy: false

    width: parent ? parent.width : 0
    spacing: 18

    readonly property bool paired: !!s.address
    readonly property bool adapter: s.adapter !== false

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        source: "../assets/set.png"
        width: 280
        height: 184
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: 0.9
        smooth: true
    }

    Column {
        width: parent.width
        spacing: 6
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: !root.daemon ? "Pinna servisi çalışmıyor"
                : !root.adapter ? "Bluetooth kapalı"
                : !root.paired ? "Eşli AirPods yok"
                : (root.s.name || "AirPods") + " bağlı değil"
            font: Theme.title
            color: Theme.text
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: !root.daemon ? "Kulaklıkla konuşan arka plan servisi kapalı. Başlatınca ayarlar burada görünür."
                : !root.adapter ? "Bağlanmak için Bluetooth'u aç."
                : !root.paired ? "Kutunun arkasındaki düğmeye basılı tut, sonra sistemin Bluetooth ayarlarından eşleştir."
                : "Kutuyu aç ve yakınında tut ya da aşağıdan bağlan."
            font: Theme.body
            color: Theme.text2
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }

    Rectangle {
        visible: root.paired || !root.daemon || !root.adapter
        anchors.horizontalCenter: parent.horizontalCenter
        width: 200
        height: 44
        radius: 22
        color: btn.pressed ? Qt.darker(Theme.accent, 1.12) : Theme.accent
        opacity: root.busy ? 0.6 : 1

        Text {
            anchors.centerIn: parent
            text: root.busy ? "Bağlanıyor…"
                : !root.daemon ? "Servisi başlat"
                : !root.adapter ? "Bluetooth'u aç ve bağlan"
                : "Bağlan"
            font: Theme.label
            color: Theme.accentText
        }

        MouseArea {
            id: btn
            anchors.fill: parent
            enabled: !root.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.daemon) {
                    Backend.startDaemon()
                    return
                }
                root.busy = true
                busyTimer.restart()
                Backend.connectDevice()
            }
        }
    }

    Timer {
        id: busyTimer
        interval: 12000
        onTriggered: root.busy = false
    }
    Connections {
        target: Backend
        function onStateChanged() { if (Backend.state.connected) root.busy = false }
        function onError() { root.busy = false }
    }
}
