import QtQuick
import Pinna

// Kulaklık bağlı değilken görünen ekran: yükleniyor, servis kapalı, Bluetooth kapalı, eşli aygıt yok ya da bağlı değil.
Item {
    id: root
    readonly property var s: Store.s
    readonly property string kind: !Backend.daemon ? "daemon"
        : !Store.loaded ? "loading"
        : s.adapter === false ? "bluetooth"
        : !s.address ? "unpaired"
        : "away"
    property bool busy: false
    property string failure

    onKindChanged: {
        busy = false
        failure = ""
        swap.restart()
    }

    function act() {
        failure = ""
        busy = true
        busyTimer.restart()
        if (kind === "daemon") Backend.startDaemon()
        else Backend.connectDevice()
    }

    Timer {
        id: busyTimer
        interval: 15000
        onTriggered: {
            root.busy = false
            root.failure = root.kind === "daemon" ? "Servis başlatılamadı. Terminalde 'systemctl --user status pinnad' çıktısına bak."
                : "Bağlanılamadı. Kutuyu aç ve AirPods'u bilgisayara yakın tut."
        }
    }
    Connections {
        target: Backend
        function onStateChanged() { if (Store.live) root.busy = false }
        function onError(m) {
            root.busy = false
            root.failure = m
        }
    }

    // durum değişince içerik hafifçe aşağıdan yeniden gelir
    ParallelAnimation {
        id: swap
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 260 }
        NumberAnimation { target: content; property: "shift"; from: Theme.reduce ? 0 : 14; to: 0; duration: 520; easing.type: Easing.OutQuint }
    }

    Column {
        id: content
        property real shift: 0
        visible: root.kind !== "loading"
        width: parent.width - 64
        x: 32
        y: (parent.height - height) / 2 - 20 + shift
        spacing: 22

        Item {
            width: parent.width
            height: 170
            PodArt {
                id: art
                anchors.centerIn: parent
                scaleFactor: 0.95
                leftActive: root.kind === "away"
                rightActive: root.kind === "away"
            }
        }

        Column {
            width: parent.width
            spacing: 8
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.kind === "daemon" ? "Pinna servisi çalışmıyor"
                    : root.kind === "bluetooth" ? "Bluetooth kapalı"
                    : root.kind === "unpaired" ? "Eşli AirPods yok"
                    : Store.name + " bağlı değil"
                font: Theme.title
                color: Theme.text
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.kind === "daemon" ? "Kulaklıkla konuşan arka plan servisi kapalı. Başlatınca ayarlar burada görünür."
                    : root.kind === "bluetooth" ? "AirPods'a bağlanmak için bilgisayarın Bluetooth'unu aç."
                    : root.kind === "unpaired" ? "AirPods kutudayken kapağı aç, kutunun arkasındaki düğmeye ışık beyaz yanıp sönene kadar basılı tut. Sonra sistemin Bluetooth ayarlarından eşleştir."
                    : "Kutuyu aç ve AirPods'u yakınında tut, ya da aşağıdan bağlan."
                font: Theme.body
                color: Theme.text2
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }

        PillButton {
            visible: root.kind !== "unpaired"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            busy: root.busy
            text: root.busy ? (root.kind === "daemon" ? "Başlatılıyor…" : "Bağlanıyor…")
                : root.kind === "daemon" ? "Servisi Başlat"
                : root.kind === "bluetooth" ? "Bluetooth'u Aç ve Bağlan"
                : "Bağlan"
            onClicked: root.act()
        }

        Text {
            visible: root.failure.length > 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.failure
            font: Theme.footnote
            color: Theme.red
            wrapMode: Text.WordWrap
        }
    }

    Column {
        visible: root.kind === "loading"
        anchors.centerIn: parent
        spacing: 12
        Spinner { anchors.horizontalCenter: parent.horizontalCenter; size: 26 }
        Text {
            text: "Yükleniyor…"
            font: Theme.footnote
            color: Theme.text2
        }
    }
}
