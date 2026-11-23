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

    // kulaklık işaretli basışları kendisi işlemez, bize iletir; bilgisayarda istenen her şeye bağlanabilir
    Section {
        id: press
        title: qsTr("Basış Kısayolları")
        footer: qsTr("Basışları bu bilgisayarda bir işe bağla. Atanmamış basışlar her zamanki gibi çalışır.")
        enabled: Store.ready
        property string side: "left"
        readonly property var actions: ["", "playPause", "next", "previous", "volumeUp", "volumeDown", "micMute", "mode", "ancTransparency", "nothing", "cmd"]
        readonly property var names: [qsTr("Oynat / Duraklat"), qsTr("Sonraki parça"), qsTr("Önceki parça"), qsTr("Sesi aç"),
            qsTr("Sesi kıs"), qsTr("Mikrofonu sustur"), qsTr("Dinleme modunu değiştir"), qsTr("Gürültü engelleme / Şeffaf"), qsTr("Hiçbir şey"), qsTr("Komut çalıştır…")]
        function value(slot) {
            const k = "stem." + slot
            const v = Store.prefs[k]
            return v !== undefined ? v : ((Store.prefs.stem || {})[slot] || "")
        }
        Setting {
            title: qsTr("Kulaklık")
            Segmented {
                options: [qsTr("Sol"), qsTr("Sağ")]
                current: press.side === "left" ? 0 : 1
                onPicked: i => press.side = i === 0 ? "left" : "right"
            }
        }
        Repeater {
            model: [["double", qsTr("Çift basış"), qsTr("Varsayılan: sonraki parça")],
                    ["triple", qsTr("Üç kez basış"), qsTr("Varsayılan: önceki parça")],
                    ["long", qsTr("Basılı tutma"), qsTr("Varsayılan: yukarıdaki ayar")]]
            Setting {
                id: row
                required property var modelData
                readonly property string slot: modelData[0] + "." + press.side
                readonly property string cur: press.value(slot)
                readonly property bool isCmd: cur.startsWith("cmd:") || picker.currentIndex === 10
                title: modelData[1]
                subtitle: cur === "" ? modelData[2] : ""
                Field {
                    id: cmd
                    visible: row.isCmd
                    width: 180
                    placeholderText: qsTr("ör. grim ~/ekran.png")
                    text: row.cur.startsWith("cmd:") ? row.cur.slice(4) : ""
                    Accessible.name: qsTr("Komut")
                    onAccepted: { if (text.trim()) Backend.setPref("stem." + row.slot, "cmd:" + text.trim()); focus = false }
                }
                Dropdown {
                    id: picker
                    model: [qsTr("Varsayılan")].concat(press.names)
                    currentIndex: row.cur.startsWith("cmd:") ? 10 : Math.max(0, press.actions.indexOf(row.cur))
                    Accessible.name: row.title
                    onPicked: i => {
                        if (i === 10) { cmd.forceActiveFocus(); return }
                        Backend.setPref("stem." + row.slot, press.actions[i])
                    }
                }
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
