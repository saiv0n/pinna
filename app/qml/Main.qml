import QtQuick
import QtQuick.Layouts
import Pinna

Window {
    id: win
    width: typeof pinnaWidth === "number" && pinnaWidth > 0 ? pinnaWidth : 900
    height: 620
    minimumWidth: 720
    minimumHeight: 520
    visible: false
    title: "Pinna"
    color: Theme.bg

    property int page: 0
    readonly property var pages: [qsTr("Genel"), qsTr("Gürültü Kontrolü"), qsTr("Kontroller"), qsTr("Ses"),
                                  qsTr("Erişilebilirlik"), qsTr("Bu Bilgisayar"), qsTr("Hakkında")]
    function go(i, focusPage) {
        page = i
        if (focusPage) stack.children[i].forceActiveFocus()
    }

    // kapatınca tepside kalsın; tepsi yoksa ya da istenmiyorsa çık
    onClosing: close => {
        if (Backend.trayAvailable && Backend.closeToTray) {
            close.accepted = false
            win.hide()
            // tepsideyken arayüzün belleği boşa durmasın
            Backend.releaseWindow()
        } else {
            Qt.quit()
        }
    }

    // içerik alanının hangi durumu göstereceği; Bu Bilgisayar ve Hakkında her zaman açılır
    readonly property bool devicePage: page <= 4
    readonly property string blocker: !devicePage ? ""
        : !Backend.daemon ? "service"
        : Store.s.adapter === false ? "bluetooth"
        : Store.devices.length === 0 && !Store.s.address ? "setup"
        : ""

    Repeater {
        model: 7
        Item {
            required property int index
            Shortcut { sequence: "Ctrl+" + (index + 1); onActivated: win.go(index, true) }
        }
    }
    Shortcut { sequences: [StandardKey.Close]; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+PgDown"; onActivated: win.go((win.page + 1) % 7, true) }
    Shortcut { sequence: "Ctrl+PgUp"; onActivated: win.go((win.page + 6) % 7, true) }

    // kenar çubuğu da son bilinen kutu pilini buradan okuyor
    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Backend.daemon
        onTriggered: Backend.loadHistory()
    }
    Connections { target: Store; function onLiveChanged() { Backend.loadHistory() } }

    Sidebar {
        id: side
        height: parent.height
        pages: win.pages
        current: win.page
        onPicked: i => win.go(i)
        onPair: { win.go(0); general.startPairing() }
    }

    Item {
        x: side.width
        width: parent.width - side.width
        height: parent.height

        // servis ya da bağlantı yoksa sayfanın üstünde dürüst bir şerit
        Rectangle {
            id: strip
            width: parent.width
            height: visible ? 40 : 0
            visible: win.blocker === "" && Backend.daemon && !Store.live && win.page >= 1 && win.page <= 4
            color: Theme.dark ? "#2a2620" : "#fff6e5"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            Text {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - stripButton.width - 40
                elide: Text.ElideRight
                text: qsTr("%1 bağlı değil. Bu ayarlar bağlanınca değiştirilebilir.").arg(Store.name)
                font: Theme.body
                color: Theme.text
            }
            Button {
                id: stripButton
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Bağlan")
                onClicked: Backend.connectDevice()
            }
        }

        StackLayout {
            id: stack
            y: strip.height
            width: parent.width
            height: parent.height - y
            currentIndex: win.page
            visible: win.blocker === ""
            GeneralPage { id: general; confirm: confirm }
            NoisePage {}
            ControlsPage {}
            AudioPage {}
            AccessibilityPage {}
            ComputerPage { confirm: confirm }
            AboutPage {}
        }

        StatusView {
            anchors.fill: parent
            visible: win.blocker === "service"
            title: qsTr("Pinna servisi çalışmıyor")
            text: qsTr("Kulaklıkla konuşan arka plan servisi kapalı. Başlatınca ayarların hepsi yeniden kullanılabilir.")
            action: qsTr("Servisi Başlat")
            onTriggered: Backend.startDaemon()
        }
        StatusView {
            anchors.fill: parent
            visible: win.blocker === "bluetooth"
            title: qsTr("Bluetooth kapalı")
            text: qsTr("AirPods'a bağlanmak ve ayarlarını değiştirmek için Bluetooth açık olmalı.")
            action: qsTr("Bluetooth'u Aç")
            onTriggered: Backend.powerOn()
        }
        Onboarding {
            anchors.fill: parent
            visible: win.blocker === "setup"
        }
    }

    Confirm { id: confirm }
    Toast { id: toast }
    Connections {
        target: Backend
        function onError(code, m) {
            const e = {
                "not-connected": [qsTr("Kulaklık bağlı değil"), qsTr("Bu ayar ancak kulaklık bağlıyken değişebilir."), qsTr("Bağlan"), () => Backend.connectDevice()],
                "bluetooth-off": [qsTr("Bluetooth kapalı"), qsTr("Kulaklığa ulaşmak için Bluetooth'u aç."), qsTr("Bluetooth'u Aç"), () => Backend.powerOn()],
                "unreachable": [qsTr("Kulaklığa ulaşılamadı"), qsTr("Kutudan çıkar ya da kapağını aç ve bilgisayarın yakınında tut."), qsTr("Yeniden Dene"), () => Backend.connectDevice()],
                "busy": [qsTr("Bluetooth meşgul"), qsTr("Başka bir işlem sürüyor. Birkaç saniye sonra yeniden dene.")],
                "service": [qsTr("Servise ulaşılamadı"), qsTr("Pinna servisi yanıt vermedi."), qsTr("Servisi Başlat"), () => Backend.startDaemon()],
                "pair-failed": [qsTr("Eşleşme tamamlanmadı"), qsTr("Kutu açıkken arkasındaki düğmeyi ışık beyaz yanıp sönene kadar basılı tut."), qsTr("Yeniden Ara"), () => Backend.discover(true)],
                "audio": [qsTr("Ses ayarı değişmedi"), qsTr("PipeWire bu kulaklık için isteği kabul etmedi. Kulaklığı çıkarıp yeniden tak.")],
                "invalid": [qsTr("Bu değer kullanılamıyor"), m],
                "no-device": [qsTr("Eşli kulaklık yok"), qsTr("Önce AirPods'unu bu bilgisayarla eşleştir."), qsTr("Eşleştir"), () => { win.go(0); Backend.discover(true) }],
                "deviceid": [qsTr("DeviceID eklenmedi"), m],
                "file": [qsTr("Günlük kaydedilemedi"), m]
            }[code] || [qsTr("Bir şey ters gitti"), m]
            toast.show(e[0], e[1], true, e[2], e[3])
        }
        function onNotice(m) { toast.show(m, "", false) }
    }

    // ekran görüntüsü için doğrudan bir sayfayla açılabilsin
    Component.onCompleted: {
        const p = typeof pinnaPage === "string" ? parseInt(pinnaPage) : NaN
        if (!isNaN(p)) page = p
    }
}
