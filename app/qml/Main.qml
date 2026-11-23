import QtQuick
import QtQuick.Layouts
import Pinna

Window {
    id: win
    width: 900
    height: 620
    minimumWidth: 720
    minimumHeight: 520
    visible: !(typeof pinnaHidden === "boolean" && pinnaHidden)
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
        } else {
            Qt.quit()
        }
    }

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
            visible: !Backend.daemon || (!Store.live && win.page >= 1 && win.page <= 4)
            color: Theme.dark ? "#2a2620" : "#fff6e5"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            Text {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - stripButton.width - 40
                elide: Text.ElideRight
                text: !Backend.daemon ? qsTr("Pinna servisi çalışmıyor. Ayarlar kulaklığa gönderilemez.")
                                      : qsTr("%1 bağlı değil. Bu ayarlar bağlanınca değiştirilebilir.").arg(Store.name)
                font: Theme.body
                color: Theme.text
            }
            Button {
                id: stripButton
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: Backend.daemon ? qsTr("Bağlan") : qsTr("Servisi Başlat")
                onClicked: Backend.daemon ? Backend.connectDevice() : Backend.startDaemon()
            }
        }

        StackLayout {
            id: stack
            y: strip.height
            width: parent.width
            height: parent.height - y
            currentIndex: win.page
            GeneralPage { id: general; confirm: confirm }
            NoisePage {}
            ControlsPage {}
            AudioPage {}
            AccessibilityPage {}
            ComputerPage { confirm: confirm }
            AboutPage {}
        }
    }

    Confirm { id: confirm }
    Toast { id: toast }
    Connections {
        target: Backend
        function onError(m) { toast.show(m, true) }
        function onNotice(m) { toast.show(m, false) }
    }

    // ekran görüntüsü için doğrudan bir sayfayla açılabilsin
    Component.onCompleted: {
        const p = typeof pinnaPage === "string" ? parseInt(pinnaPage) : NaN
        if (!isNaN(p)) page = p
    }
}
