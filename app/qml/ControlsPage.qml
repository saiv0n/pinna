import QtQuick
import Pinna

Page {
    id: page
    title: qsTr("Kontroller")
    // pencere kapanınca akış açık kalıp pil yemesin
    Component.onDestruction: if (Store.s.headTracking) Backend.headTracking(false)

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
        title: qsTr("Baş Takibi")
        footer: qsTr("Kulaklığın hareket algılayıcısı başının yönünü canlı gösterir. Açıkken pil biraz daha hızlı biter.")
        enabled: Store.ready
        Setting {
            id: head
            readonly property bool on: !!Store.s.headTracking
            title: qsTr("Canlı görünüm")
            subtitle: on && !Backend.head.length ? qsTr("Kulaklıktan veri bekleniyor…") : ""
            Switch { checked: head.on; onToggled: v => Backend.headTracking(v) }
        }
        Block {
            visible: head.on
            HeadView { width: parent.width }
        }
    }
}
