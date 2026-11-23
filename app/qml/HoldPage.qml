import QtQuick
import Pinna

// Bir AirPod'u basılı tutunca ne olacağı.
NavPage {
    id: page
    property string side: "left"
    title: side === "left" ? "Sol" : "Sağ"
    backTitle: Store.name

    readonly property string key: side === "left" ? "holdLeft" : "holdRight"
    readonly property int action: Store.setting(key, 1)
    readonly property int mask: Store.setting("listeningCycle", 14)
    readonly property bool allowOff: Store.setting("allowOff", true)

    Group {
        title: "Basılı Tutma"
        enabled: Store.ready
        CheckRow {
            title: "Gürültü Kontrolü"
            checked: page.action === 1
            onToggled: Backend.setSetting(page.key, 1)
        }
        CheckRow {
            title: "Siri"
            checked: page.action === 5
            onToggled: Backend.setSetting(page.key, 5)
        }
    }

    Group {
        title: "Gürültü Kontrolü"
        visible: page.action === 1
        enabled: Store.ready
        footer: "Basılı tutunca seçili modlar arasında sırayla geçilir. En az iki mod seçili kalmalı. Bu liste iki AirPod için ortaktır."

        Repeater {
            model: Store.cycleBits.filter(m => page.allowOff || m.key !== "off")
            CheckRow {
                id: row
                required property var modelData
                readonly property int count: [1, 2, 4, 8].filter(b => page.mask & b).length
                title: Store.modeNames[modelData.key]
                checked: (page.mask & modelData.bit) !== 0
                locked: count <= 2
                onToggled: v => Backend.setSetting("listeningCycle", v ? (page.mask | modelData.bit) : (page.mask & ~modelData.bit))

                ModeIcon {
                    parent: row
                    x: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    mode: row.modelData.key
                    color: Theme.accent
                }
                leftInset: 58
            }
        }
    }
}
