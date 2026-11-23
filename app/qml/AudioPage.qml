import QtQuick
import Pinna

Page {
    title: qsTr("Ses")
    readonly property var a: Store.audio

    Section {
        title: qsTr("Bu Bilgisayarda Çıkış")
        footer: a.available ? "" : qsTr("PipeWire bu kulaklık için henüz bir ses çıkışı açmadı.")
        enabled: Store.live && !!a.available
        Setting {
            title: qsTr("Varsayılan çıkış")
            subtitle: a.isDefault ? qsTr("Sistem sesi bu kulaklıktan çıkıyor.") : qsTr("Sistem sesi başka bir aygıttan çıkıyor.")
            Button {
                visible: !a.isDefault
                text: qsTr("Bunu Kullan")
                onClicked: Backend.setAudio("default", true)
            }
        }
        Block {
            Item {
                width: parent.width
                height: 20
                Text { text: qsTr("Ses düzeyi"); font: Theme.body; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Text { anchors.right: parent.right; text: (a.volume || 0) + "%"; font: Theme.footnote; color: Theme.text2; anchors.verticalCenter: parent.verticalCenter }
            }
            Slider {
                width: parent.width
                from: 0
                to: 100
                target: a.volume || 0
                onCommitted: v => Backend.setAudio("volume", Math.round(v))
            }
        }
    }

    Section {
        title: qsTr("Görüşmeler")
        footer: a.profile === "hfp"
            ? qsTr("Kulaklığın mikrofonu açıkken Bluetooth ses kalitesini telefon düzeyine indirir (%1).").arg(a.codec || "HFP")
            : qsTr("Discord gibi uygulamalarda ses bozuluyorsa yüksek kaliteyi açık tut.")
        Setting {
            title: qsTr("Görüşmede yüksek kaliteli ses")
            subtitle: qsTr("Kulaklık müzik kalitesinde kalır, mikrofon olarak bilgisayarınki kullanılır.")
            enabled: Backend.daemon
            Switch {
                checked: Store.pref("callQuality", true)
                onToggled: v => Backend.setPref("callQuality", v)
            }
        }
        Setting {
            title: qsTr("Kulaklığın mikrofonu")
            subtitle: a.profile === "hfp" ? qsTr("Açık, %1.").arg(a.codec || "HFP") : qsTr("Kapalı, %1.").arg(a.codec || "A2DP")
            enabled: Store.live && !!a.available
            Segmented {
                options: [qsTr("Kapalı"), qsTr("Açık")]
                current: a.profile === "hfp" ? 1 : 0
                onPicked: i => Backend.setAudio("profile", i ? "hfp" : "a2dp")
            }
        }
    }

    Section {
        Setting {
            title: qsTr("Bağlanınca bu kulaklığa geç")
            subtitle: qsTr("Kulaklık bağlanınca sistem sesi kendiliğinden ona yönlendirilir.")
            enabled: Backend.daemon
            Switch {
                checked: Store.pref("autoOutput", true)
                onToggled: v => Backend.setPref("autoOutput", v)
            }
        }
    }

    Section {
        title: qsTr("Akıllı Ses")
        Setting {
            title: qsTr("Kişiselleştirilmiş ses düzeyi")
            subtitle: qsTr("Ortama ve dinleme alışkanlığına göre ses düzeyi ayarlanır.")
            enabled: Store.ready
            Switch {
                checked: Store.setting("adaptiveVolume", false)
                onToggled: v => Backend.setSetting("adaptiveVolume", v)
            }
        }
        Setting {
            title: qsTr("Konuşunca bilgisayarın sesini kıs")
            enabled: Backend.daemon
            Switch {
                checked: Store.pref("duckOnSpeech", true)
                onToggled: v => Backend.setPref("duckOnSpeech", v)
            }
        }
        Block {
            visible: Store.pref("duckOnSpeech", true)
            Item {
                width: parent.width
                height: 20
                Text { text: qsTr("Kısılınca kalan ses"); font: Theme.body; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Text { anchors.right: parent.right; text: Store.pref("duckLevel", 25) + "%"; font: Theme.footnote; color: Theme.text2; anchors.verticalCenter: parent.verticalCenter }
            }
            Slider {
                width: parent.width
                from: 0
                to: 100
                target: Store.pref("duckLevel", 25)
                onCommitted: v => Backend.setPref("duckLevel", Math.round(v))
            }
        }
    }

    Section {
        title: qsTr("Kutu Hoparlörü")
        enabled: Store.ready
        Block {
            Text { text: qsTr("Bildirim seslerinin düzeyi"); font: Theme.body; color: Theme.text }
            Slider {
                width: parent.width
                from: 0
                to: 100
                target: Store.setting("chimeVolume", 80)
                onCommitted: v => Backend.setSetting("chimeVolume", Math.round(v))
            }
        }
    }
}
