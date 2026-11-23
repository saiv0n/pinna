import QtQuick
import Pinna

NavPage {
    id: page
    title: Store.name
    titleAfter: hero.y + hero.nameItem.y + hero.nameItem.height - barHeight - 12
    signal open(url page, var props)

    readonly property bool ready: Store.ready

    function holdText(side) {
        return Store.setting(side === "left" ? "holdLeft" : "holdRight", 1) === 5 ? "Siri" : "Gürültü Kontrolü"
    }

    Hero { id: hero }

    Group {
        title: "Gürültü Kontrolü"
        visible: !!Store.s.mode
        enabled: page.ready

        Item {
            width: parent.width
            height: modes.height + 24
            ModeSwitch {
                id: modes
                x: 12
                y: 12
                width: parent.width - 24
                mode: Store.s.mode || ""
                allowOff: Store.setting("allowOff", true)
                onPicked: m => Backend.setMode(m)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                x: Theme.pad
                width: parent.width - x
                height: 1
                color: Theme.separator
            }
        }
        SliderRow {
            visible: modes.shown === "adaptive"
            leftLabel: "Daha çok ortam sesi"
            rightLabel: "Daha az ortam sesi"
            value: Store.setting("adaptiveStrength", 50)
            onCommitted: v => Backend.setSetting("adaptiveStrength", v)
        }
        ToggleRow {
            title: "Kapalı Seçeneğine İzin Ver"
            checked: Store.setting("allowOff", true)
            onToggled: v => Backend.setSetting("allowOff", v)
        }
    }

    Group {
        title: "Basılı Tutma"
        enabled: page.ready
        SettingRow {
            title: "Sol"
            value: page.holdText("left")
            chevron: true
            onClicked: page.open(Qt.resolvedUrl("HoldPage.qml"), { side: "left" })
        }
        SettingRow {
            title: "Sağ"
            value: page.holdText("right")
            chevron: true
            onClicked: page.open(Qt.resolvedUrl("HoldPage.qml"), { side: "right" })
        }
    }

    Group {
        enabled: page.ready
        footer: "Konuşmaya başlayınca medyanın sesi kısılır, önündeki kişinin sesi öne çıkar. Kişiselleştirilmiş ses düzeyi ortama ve dinleme alışkanlığına göre ses düzeyini ayarlar."
        ToggleRow {
            title: "Konuşma Algılama"
            checked: Store.setting("conversationAwareness", false)
            onToggled: v => Backend.setSetting("conversationAwareness", v)
        }
        ToggleRow {
            title: "Kişiselleştirilmiş Ses Düzeyi"
            checked: Store.setting("adaptiveVolume", false)
            onToggled: v => Backend.setSetting("adaptiveVolume", v)
        }
    }

    Group {
        enabled: page.ready
        footer: "Uykuya daldığını fark edince çalan medya duraklatılır."
        ToggleRow {
            title: "Uyku Algılama"
            checked: Store.setting("sleepDetection", false)
            onToggled: v => Backend.setSetting("sleepDetection", v)
        }
    }

    Group {
        SettingRow {
            title: "Ad"
            value: Store.name
            chevron: true
            enabled: page.ready
            onClicked: page.open(Qt.resolvedUrl("NamePage.qml"), {})
        }
        SettingRow {
            title: "Erişilebilirlik"
            chevron: true
            enabled: page.ready
            onClicked: page.open(Qt.resolvedUrl("AccessibilityPage.qml"), {})
        }
        SettingRow {
            title: "Bu Bilgisayarda"
            chevron: true
            onClicked: page.open(Qt.resolvedUrl("ComputerPage.qml"), {})
        }
    }

    Group {
        enabled: page.ready
        footer: "Açıkken AirPods yakındaki aygıtlar arasında kendiliğinden bu bilgisayara geçebilir."
        ToggleRow {
            title: "Otomatik Bağlan"
            checked: Store.setting("autoConnect", true)
            onToggled: v => Backend.setSetting("autoConnect", v)
        }
    }

    Group {
        title: "Hakkında"
        InfoRow { title: "Model Adı"; text: Store.s.modelName || "AirPods" }
        InfoRow { title: "Model Numarası"; text: Store.s.model || "—" }
        InfoRow { title: "Seri Numarası"; text: Store.s.serial || "—" }
        InfoRow { title: "Sol AirPod"; text: Store.s.serialLeft || "—"; visible: !!Store.s.serialLeft }
        InfoRow { title: "Sağ AirPod"; text: Store.s.serialRight || "—"; visible: !!Store.s.serialRight }
        InfoRow { title: "Sürüm"; text: Store.s.firmware || "—" }
        InfoRow { title: "Bluetooth"; text: Store.s.address || "—" }
    }

    Group {
        SettingRow {
            title: "Bağlantıyı Kes"
            titleColor: Theme.accent
            centered: true
            clickable: true
            onClicked: Backend.disconnectDevice()
        }
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Kulaklık görseli Jed Falcone'un AirPods Pro modelinden (CC BY 4.0).\nPinna'nın Apple ile bir bağı yoktur."
        font: Theme.caption
        color: Theme.text3
        lineHeight: 1.2
    }
}
