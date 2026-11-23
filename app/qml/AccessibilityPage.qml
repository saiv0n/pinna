import QtQuick
import Pinna

Page {
    title: qsTr("Erişilebilirlik")

    Section {
        enabled: Store.ready
        Setting {
            title: qsTr("İşitme desteği")
            subtitle: qsTr("Konuşmaları ve çevre sesini daha net duymana yardım eder.")
            Switch {
                checked: Store.setting("hearingAssist", false)
                onToggled: v => Backend.setSetting("hearingAssist", v)
            }
        }
        Setting {
            title: qsTr("Uyku algılama")
            subtitle: qsTr("Uykuya daldığını fark edince çalan medya duraklatılır.")
            Switch {
                checked: Store.setting("sleepDetection", false)
                onToggled: v => Backend.setSetting("sleepDetection", v)
            }
        }
    }

    Section {
        title: qsTr("Henüz Desteklenmiyor")
        footer: qsTr("Bu iki ayarın paket biçimi kısmen biliniyor ama kulaklığın şu anki değerleri okunamıyor. Yanlış değer yazıp işitme ayarını bozmamak için Pinna şimdilik bunlara dokunmuyor.")
        Setting {
            title: qsTr("Kulaklık uyarlama")
            subtitle: qsTr("Telefon ve medya sesini işitmene göre ayarlar.")
            enabled: false
            Text { text: qsTr("Yok"); font: Theme.footnote; color: Theme.text3 }
        }
        Setting {
            title: qsTr("Şeffaflık modunu özelleştir")
            subtitle: qsTr("Yükseltme, ton ve ortam gürültüsü azaltma.")
            enabled: false
            Text { text: qsTr("Yok"); font: Theme.footnote; color: Theme.text3 }
        }
    }
}
