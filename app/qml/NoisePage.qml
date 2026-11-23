import QtQuick
import Pinna

Page {
    id: page
    title: qsTr("Gürültü Kontrolü")
    subtitle: qsTr("Dış seslerin ne kadarını duyacağını seç. Değişiklik kulaklığa hemen gider.")
    readonly property int mask: Store.setting("listeningCycle", 14)
    readonly property bool allowOff: Store.setting("allowOff", true)

    Section {
        enabled: Store.ready
        Block {
            ModePicker { width: parent.width }
        }
        Block {
            visible: Store.s.mode === "adaptive"
            Text { text: qsTr("Uyarlanabilir modda ortam sesi"); font: Theme.body; color: Theme.text }
            Slider {
                width: parent.width
                from: 0
                to: 100
                target: Store.setting("adaptiveStrength", 50)
                onCommitted: v => Backend.setSetting("adaptiveStrength", Math.round(v))
            }
            Item {
                width: parent.width
                height: 14
                Text { text: qsTr("Daha çok ortam sesi"); font: Theme.caption; color: Theme.text2 }
                Text { anchors.right: parent.right; text: qsTr("Daha az ortam sesi"); font: Theme.caption; color: Theme.text2 }
            }
        }
    }

    Section {
        title: qsTr("Basılı Tutunca Geçilecek Modlar")
        footer: qsTr("Sapı basılı tutunca seçili modlar arasında sırayla geçilir. En az iki mod seçili kalmalı.")
        enabled: Store.ready
        Repeater {
            model: Store.cycleBits
            Setting {
                id: row
                required property var modelData
                readonly property int count: [1, 2, 4, 8].filter(b => page.mask & b).length
                readonly property bool on: (page.mask & modelData.bit) !== 0
                visible: page.allowOff || modelData.key !== "off"
                title: Store.modeNames[modelData.key]
                clickable: true
                onClicked: box.flip()
                CheckBox {
                    id: box
                    checked: row.on
                    locked: row.count <= 2
                    onToggled: v => Backend.setSetting("listeningCycle", v ? (page.mask | row.modelData.bit) : (page.mask & ~row.modelData.bit))
                }
            }
        }
        Setting {
            title: qsTr("Kapalı seçeneğine izin ver")
            Switch {
                checked: page.allowOff
                onToggled: v => Backend.setSetting("allowOff", v)
            }
        }
    }

    Section {
        enabled: Store.ready
        Setting {
            title: qsTr("Konuşma Algılama")
            subtitle: qsTr("Konuşmaya başlayınca medya kısılır, karşındakinin sesi öne çıkar.")
            Switch {
                checked: Store.setting("conversationAwareness", false)
                onToggled: v => Backend.setSetting("conversationAwareness", v)
            }
        }
        Setting {
            title: qsTr("Tek kulaklıkta konuşma algılamayı durdur")
            subtitle: qsTr("Tek AirPod takılıyken konuşma algılama kapanır, ikisini takınca geri açılır.")
            enabled: Store.setting("conversationAwareness", false) || Store.pref("caOneBud", false)
            Switch {
                checked: Store.pref("caOneBud", false)
                onToggled: v => Backend.setPref("caOneBud", v)
            }
        }
        Setting {
            title: qsTr("Tek AirPod ile Gürültü Engelleme")
            subtitle: qsTr("Yalnızca bir AirPod takılıyken de gürültü engelleme açık kalır.")
            Switch {
                checked: Store.setting("oneBudAnc", false)
                onToggled: v => Backend.setSetting("oneBudAnc", v)
            }
        }
    }
}
