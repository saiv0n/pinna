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
        title: qsTr("Uzamsal Ses")
        footer: Store.pref("spatial", "off") === "head"
            ? qsTr("Ses önündeki iki hoparlörden geliyormuş gibi duyulur ve başını çevirince yerinde kalır. Uzun süre yana bakarsan ses de yavaşça oraya yerleşir. Baş takibi pili biraz daha hızlı bitirir.")
            : qsTr("Stereo ses, kafanın içinde değil önündeki iki hoparlörden geliyormuş gibi duyulur.")
        enabled: Store.live
        Setting {
            title: qsTr("Uzamsal ses")
            subtitle: Store.pref("spatial", "off") !== "off" && !Store.audio.available ? qsTr("Ses çıkışı bekleniyor…") : ""
            Segmented {
                readonly property var keys: ["off", "fixed", "head"]
                options: [qsTr("Kapalı"), qsTr("Sabit"), qsTr("Baş takipli")]
                current: Math.max(0, keys.indexOf(Store.pref("spatial", "off")))
                onPicked: i => Backend.setPref("spatial", keys[i])
            }
        }
    }

    Section {
        id: calls
        title: qsTr("Görüşmeler")
        readonly property string mode: Store.pref("callMic", "computer")
        footer: mode === "airpods"
            ? qsTr("Kulaklık müzik kalitesinde kalır, mikrofonu ayrı bir kanaldan gelir. Uygulama başka bir mikrofon kullanıyorsa adı \"(Pinna)\" ile biteni seç. Deneysel.")
            : mode === "hfp"
            ? qsTr("Mikrofon açılınca kulaklık telefon profiline geçer, müzik de telefon kalitesine düşer. Değişiklik bir sonraki bağlanışta geçerli olur.")
            : qsTr("Kulaklık müzik kalitesinde kalır, mikrofon olarak bilgisayarınki kullanılır.")
        Setting {
            title: qsTr("Görüşmede mikrofon")
            enabled: Backend.daemon
            Dropdown {
                readonly property var modes: ["computer", "airpods", "hfp"]
                model: [qsTr("Bilgisayarın"), qsTr("AirPods, yüksek kalite"), qsTr("AirPods, telefon kalitesi")]
                currentIndex: Math.max(0, modes.indexOf(calls.mode))
                onPicked: i => Backend.setPref("callMic", modes[i])
            }
        }
        Setting {
            title: qsTr("Şu anki kalite")
            enabled: Store.live && !!a.available
            subtitle: a.profile === "hfp"
                ? qsTr("Kulaklık ve mikrofon %1, telefon kalitesi").arg(a.codec || "HFP")
                : calls.mode === "airpods"
                ? (a.micActive ? qsTr("Kulaklık %1, mikrofon AAC-ELD 64 kHz, açık").arg(a.codec || "A2DP")
                               : qsTr("Kulaklık %1, mikrofon bir uygulama dinleyince açılır").arg(a.codec || "A2DP"))
                : qsTr("Kulaklık %1, mikrofon bilgisayarın").arg(a.codec || "A2DP")
            Rectangle {
                visible: !!a.micActive || a.profile === "hfp"
                width: 8
                height: 8
                radius: 4
                color: a.profile === "hfp" ? Theme.orange : Theme.green
            }
        }
        Setting {
            visible: calls.mode === "hfp"
            title: qsTr("Kulaklığın mikrofonu")
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
