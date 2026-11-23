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
}
