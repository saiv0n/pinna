import QtQuick
import Pinna

Page {
    title: qsTr("Accessibility")

    Section {
        enabled: Store.ready
        Setting {
            title: qsTr("Hearing assistance")
            subtitle: qsTr("Helps you hear conversations and your surroundings more clearly.")
            Switch {
                checked: Store.setting("hearingAssist", false)
                onToggled: v => Backend.setSetting("hearingAssist", v)
            }
        }
        Setting {
            title: qsTr("Sleep detection")
            subtitle: qsTr("Media is paused when you fall asleep.")
            Switch {
                checked: Store.setting("sleepDetection", false)
                onToggled: v => Backend.setSetting("sleepDetection", v)
            }
        }
    }
}
