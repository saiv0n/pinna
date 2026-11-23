import QtQuick
import Pinna

// Kulaklığa değil Pinna'ya ait tercihler.
NavPage {
    title: "Bu Bilgisayarda"
    backTitle: Store.name

    Group {
        title: "Otomatik Kulak Algılama"
        footer: "Bir AirPod'u kulağından çıkarınca çalan medya durur, geri takınca devam eder."
        ToggleRow {
            title: "Çıkarınca Duraklat"
            checked: Store.pref("autoPause", true)
            onToggled: v => Backend.setPref("autoPause", v)
        }
        ToggleRow {
            title: "Takınca Devam Et"
            checked: Store.pref("autoResume", true)
            onToggled: v => Backend.setPref("autoResume", v)
        }
    }

    Group {
        title: "Konuşma"
        footer: "Konuşma Algılama açıkken bilgisayarın sesini de bu düzeye kadar kısar."
        ToggleRow {
            title: "Konuşurken Sesi Kıs"
            checked: Store.pref("duckOnSpeech", true)
            onToggled: v => Backend.setPref("duckOnSpeech", v)
        }
        SliderRow {
            visible: Store.pref("duckOnSpeech", true)
            speakers: true
            value: Store.pref("duckLevel", 25)
            onCommitted: v => Backend.setPref("duckLevel", v)
        }
    }

    Group {
        title: "Bildirimler"
        ToggleRow {
            title: "Bağlanınca Kart Göster"
            checked: Store.pref("popup", true)
            onToggled: v => Backend.setPref("popup", v)
        }
        ToggleRow {
            title: "Düşük Pil Bildirimi"
            checked: Store.pref("lowBatteryNotify", true)
            onToggled: v => Backend.setPref("lowBatteryNotify", v)
        }
    }

    Group {
        footer: "Bağlı değilken Bluetooth ile kutunun açılmasını dinler ve kartı gösterir. Pili biraz daha fazla kullanır."
        ToggleRow {
            title: "Kutu Açılınca Algıla"
            checked: Store.pref("caseScan", true)
            onToggled: v => Backend.setPref("caseScan", v)
        }
    }
}
