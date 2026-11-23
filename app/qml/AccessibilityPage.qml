import QtQuick
import Pinna

NavPage {
    title: "Erişilebilirlik"
    backTitle: Store.name

    Choice {
        title: "Basma Hızı"
        footer: "Çift ya da üç kez basarken basışlar arasında ne kadar süre geçebileceğini ayarlar."
        enabled: Store.ready
        options: ["Varsayılan", "Yavaş", "En Yavaş"]
        current: Store.setting("pressSpeed", 0)
        onPicked: i => Backend.setSetting("pressSpeed", i)
    }

    Choice {
        title: "Basılı Tutma Süresi"
        footer: "Basılı tutmanın algılanması için sapın ne kadar süre sıkılması gerektiğini ayarlar."
        enabled: Store.ready
        options: ["Varsayılan", "Daha Kısa", "En Kısa"]
        current: Store.setting("holdDuration", 0)
        onPicked: i => Backend.setSetting("holdDuration", i)
    }

    Group {
        enabled: Store.ready
        footer: "Yalnızca bir AirPod takılıyken de gürültü engellemeyi açık tutar."
        ToggleRow {
            title: "Tek AirPod ile Gürültü Engelleme"
            checked: Store.setting("oneBudAnc", false)
            onToggled: v => Backend.setSetting("oneBudAnc", v)
        }
    }

    Group {
        title: "Ses Kontrolü"
        enabled: Store.ready
        footer: "Sapın üzerinde parmağını yukarı ya da aşağı kaydırarak ses düzeyini değiştir."
        ToggleRow {
            title: "Kaydırarak Ses Ayarı"
            checked: Store.setting("volumeSwipe", true)
            onToggled: v => Backend.setSetting("volumeSwipe", v)
        }
    }

    Choice {
        title: "Kaydırma Uzunluğu"
        visible: Store.setting("volumeSwipe", true)
        enabled: Store.ready
        options: ["Varsayılan", "Daha Uzun", "En Uzun"]
        current: Store.setting("volumeSwipeInterval", 0)
        onPicked: i => Backend.setSetting("volumeSwipeInterval", i)
    }

    Group {
        title: "Kutu Hoparlörü Ses Düzeyi"
        enabled: Store.ready
        footer: "Kutunun çıkardığı bildirim seslerinin düzeyi."
        SliderRow {
            speakers: true
            value: Store.setting("chimeVolume", 80)
            onCommitted: v => Backend.setSetting("chimeVolume", v)
        }
    }

    Group {
        enabled: Store.ready
        footer: "Kulaklığın konuşmaları ve çevre sesini daha net duymana yardım eden işitme desteği özelliği."
        ToggleRow {
            title: "İşitme Desteği"
            checked: Store.setting("hearingAssist", false)
            onToggled: v => Backend.setSetting("hearingAssist", v)
        }
    }
}
