import QtQuick
import Pinna

Page {
    id: page
    property Item confirm
    title: qsTr("Noise Control")
    subtitle: Store.noiseControl ? qsTr("Choose how much of the outside world you hear. Changes are sent right away.")
                                 : qsTr("These headphones have no noise cancellation or transparency.")
    readonly property int mask: Store.setting("listeningCycle", 14)
    readonly property bool allowOff: Store.setting("allowOff", true)

    Section {
        visible: Store.noiseControl
        enabled: Store.ready
        Block {
            ModePicker { width: parent.width }
        }
        Block {
            visible: Store.s.mode === "adaptive" && Store.has("adaptiveStrength")
            Text { text: qsTr("Ambient sound in Adaptive mode"); font: Theme.body; color: Theme.text }
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
                Text { text: qsTr("More ambient sound"); font: Theme.caption; color: Theme.text2 }
                Text { anchors.right: parent.right; text: qsTr("Less ambient sound"); font: Theme.caption; color: Theme.text2 }
            }
        }
    }

    Section {
        visible: Store.noiseControl
        title: qsTr("Modes to Cycle Through")
        footer: qsTr("Pressing and holding the stem cycles through the selected modes. At least two must stay selected.")
        enabled: Store.ready
        Repeater {
            model: Store.cycleBits
            Setting {
                id: row
                required property var modelData
                readonly property int count: [1, 2, 4, 8].filter(b => page.mask & b).length
                readonly property bool on: (page.mask & modelData.bit) !== 0
                visible: (page.allowOff || modelData.key !== "off") && (modelData.key !== "adaptive" || Store.adaptive)
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
            title: qsTr("Allow Off option")
            Switch {
                checked: page.allowOff
                onToggled: v => Backend.setSetting("allowOff", v)
            }
        }
    }

    Section {
        enabled: Store.ready
        Setting {
            visible: Store.has("conversationAwareness")
            title: qsTr("Conversation Awareness")
            subtitle: qsTr("When you start speaking, media is lowered and voices in front of you are brought forward.")
            Switch {
                checked: Store.setting("conversationAwareness", false)
                onToggled: v => Backend.setSetting("conversationAwareness", v)
            }
        }
        Setting {
            visible: Store.has("conversationAwareness") && !Store.oneBattery
            title: qsTr("Pause Conversation Awareness with one AirPod")
            subtitle: qsTr("Conversation Awareness turns off while only one AirPod is in and comes back when both are.")
            enabled: Store.setting("conversationAwareness", false) || Store.pref("caOneBud", false)
            Switch {
                checked: Store.pref("caOneBud", false)
                onToggled: v => Backend.setPref("caOneBud", v)
            }
        }
        Setting {
            visible: Store.has("oneBudAnc") && !Store.oneBattery
            title: qsTr("Noise Cancellation with One AirPod")
            subtitle: qsTr("Keeps noise cancellation on with only one AirPod in.")
            Switch {
                checked: Store.setting("oneBudAnc", false)
                onToggled: v => Backend.setSetting("oneBudAnc", v)
            }
        }
    }

    // only models that report it, like AirPods Pro 2 on newer firmware and Pro 3
    Section {
        title: qsTr("Hearing Protection")
        visible: Store.settings.loudSoundReduction !== undefined
        enabled: Store.ready
        experimental: true
        footer: qsTr("Lowers sudden loud sounds around you in Transparency and Adaptive modes. It does not limit the volume of your music.")
        Setting {
            title: qsTr("Loud Sound Reduction")
            Switch {
                checked: Store.setting("loudSoundReduction", true)
                onToggled: v => {
                    if (v)
                        Backend.setSetting("loudSoundReduction", true)
                    else
                        page.confirm.ask(qsTr("Turn off Loud Sound Reduction?"),
                                         qsTr("Loud noise around you, like sirens or concerts, will reach your ears at full level in Transparency and Adaptive modes. Music volume stays the same either way."),
                                         "", qsTr("Turn Off"), () => Backend.setSetting("loudSoundReduction", false))
                }
            }
        }
    }
}
