import QtQuick
import Pinna

Page {
    id: page
    title: qsTr("Kontroller")

    Section {
        title: qsTr("Basılı Tutma")
        enabled: Store.ready
        Repeater {
            model: [["holdLeft", qsTr("Sol AirPod")], ["holdRight", qsTr("Sağ AirPod")]]
            Setting {
                required property var modelData
                title: modelData[1]
                Dropdown {
                    model: [qsTr("Gürültü kontrolü"), qsTr("Sesli asistan")]
                    currentIndex: Store.setting(parent.parent.modelData[0], 1) === 5 ? 1 : 0
                    onPicked: i => Backend.setSetting(parent.parent.modelData[0], i === 1 ? 5 : 1)
                }
            }
        }
        Setting {
            title: qsTr("Basma hızı")
            subtitle: qsTr("Çift ya da üç kez basarken basışlar arasında geçebilecek süre.")
            Segmented {
                options: [qsTr("Varsayılan"), qsTr("Yavaş"), qsTr("En yavaş")]
                current: Store.setting("pressSpeed", 0)
                onPicked: i => Backend.setSetting("pressSpeed", i)
            }
        }
        Setting {
            title: qsTr("Basılı tutma süresi")
            Segmented {
                options: [qsTr("Varsayılan"), qsTr("Daha kısa"), qsTr("En kısa")]
                current: Store.setting("holdDuration", 0)
                onPicked: i => Backend.setSetting("holdDuration", i)
            }
        }
    }

    Section {
        title: qsTr("Ses Düzeyi Kaydırma")
        enabled: Store.ready
        Setting {
            title: qsTr("Sapta kaydırarak ses ayarı")
            Switch {
                checked: Store.setting("volumeSwipe", true)
                onToggled: v => Backend.setSetting("volumeSwipe", v)
            }
        }
        Setting {
            title: qsTr("Kaydırma uzunluğu")
            enabled: Store.setting("volumeSwipe", true)
            Segmented {
                options: [qsTr("Varsayılan"), qsTr("Daha uzun"), qsTr("En uzun")]
                current: Store.setting("volumeSwipeInterval", 0)
                onPicked: i => Backend.setSetting("volumeSwipeInterval", i)
            }
        }
    }

    Section {
        title: qsTr("Mikrofon ve Algılama")
        enabled: Store.ready
        Setting {
            title: qsTr("Mikrofon")
            subtitle: qsTr("Otomatikte kulakta olan AirPod kullanılır.")
            Dropdown {
                model: [qsTr("Otomatik"), qsTr("Her zaman sağ"), qsTr("Her zaman sol")]
                currentIndex: Store.setting("micMode", 0)
                onPicked: i => Backend.setSetting("micMode", i)
            }
        }
        Setting {
            title: qsTr("Kulak algılama")
            subtitle: qsTr("Kulaktan çıkarınca ses kulaklıktan kesilir.")
            Switch {
                checked: Store.setting("earDetection", true)
                onToggled: v => Backend.setSetting("earDetection", v)
            }
        }
    }

    Section {
        title: qsTr("Baş Takibi")
        footer: qsTr("Deneysel. Kulaklığın hareket algılayıcısından gelen ham değerler. Bazı yazılım sürümleri bu veriyi yalnızca Apple aygıtlarına gönderiyor.")
        enabled: Store.ready
        Setting {
            id: head
            readonly property bool on: !!Store.s.headTracking
            property bool silent: false
            title: on ? (Backend.head.length ? qsTr("Veri geliyor") : silent ? qsTr("Kulaklık veri göndermedi") : qsTr("Bekleniyor…")) : qsTr("Kapalı")
            Timer { interval: 3000; running: head.on && !Backend.head.length; onTriggered: head.silent = true }
            onOnChanged: silent = false
            Button {
                text: head.on ? qsTr("Durdur") : qsTr("Başlat")
                onClicked: Backend.headTracking(!head.on)
            }
        }
        Block {
            visible: head.on
            HeadView { width: parent.width }
        }
    }
}
