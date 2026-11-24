import QtQuick
import Pinna

Page {
    title: qsTr("Audio")
    readonly property var a: Store.audio

    Section {
        title: qsTr("Output on This Computer")
        footer: a.available ? "" : qsTr("PipeWire hasn't created an audio output for these headphones yet.")
        enabled: Store.live && !!a.available
        Setting {
            title: qsTr("Default output")
            subtitle: a.isDefault ? qsTr("System audio is playing through these headphones.") : qsTr("System audio is playing through another device.")
            Button {
                visible: !a.isDefault
                text: qsTr("Use These")
                onClicked: Backend.setAudio("default", true)
            }
        }
        Block {
            Item {
                width: parent.width
                height: 20
                Text { text: qsTr("Volume"); font: Theme.body; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
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
        title: qsTr("Spatial Audio")
        experimental: true
        footer: Store.pref("spatial", "off") === "head"
            ? qsTr("Sound seems to come from two speakers in front of you and stays put when you turn your head. If you keep looking aside, it slowly settles there too. Head tracking uses a bit more battery.")
            : qsTr("Stereo sounds like it comes from two speakers in front of you instead of inside your head.")
        enabled: Store.live
        Setting {
            title: qsTr("Spatial audio")
            subtitle: Store.pref("spatial", "off") !== "off" && !Store.audio.available ? qsTr("Waiting for audio output…") : ""
            Segmented {
                readonly property var keys: Store.headSensor ? ["off", "fixed", "head"] : ["off", "fixed"]
                options: [qsTr("Off"), qsTr("Fixed"), qsTr("Head tracked")].slice(0, keys.length)
                current: Math.max(0, keys.indexOf(Store.pref("spatial", "off")))
                onPicked: i => Backend.setPref("spatial", keys[i])
            }
        }
    }

    // only shown when the buds report one; the values come back from them on every connect
    Section {
        id: eq
        title: qsTr("Equalizer")
        experimental: true
        visible: !!Store.s.eq
        enabled: Store.ready
        footer: qsTr("Changes the sound in the headphones themselves.")
        readonly property var v: Store.s.eq || ({ enabled: false, low: 50, mid: 50, high: 50 })
        function send(on, l, m, h) { Backend.setSetting("eq", [on, l, m, h].join(",")) }
        Setting {
            title: qsTr("Custom equalizer")
            Button {
                visible: eq.v.enabled && (eq.v.low !== 50 || eq.v.mid !== 50 || eq.v.high !== 50)
                text: qsTr("Reset")
                onClicked: eq.send(true, 50, 50, 50)
            }
            Switch { checked: eq.v.enabled; onToggled: on => eq.send(on, eq.v.low, eq.v.mid, eq.v.high) }
        }
        Repeater {
            model: [["low", qsTr("Bass")], ["mid", qsTr("Mids")], ["high", qsTr("Treble")]]
            Block {
                id: band
                required property var modelData
                visible: eq.v.enabled
                Column {
                    width: parent.width
                    spacing: 8
                    Item {
                        width: parent.width
                        height: label.implicitHeight
                        Text { id: label; text: band.modelData[1]; font: Theme.body; color: Theme.text }
                        Text {
                            anchors.right: parent.right
                            readonly property int d: eq.v[band.modelData[0]] - 50
                            text: d === 0 ? qsTr("Flat") : (d > 0 ? "+" : "") + d
                            font: Theme.footnote
                            color: Theme.text2
                        }
                    }
                    Slider {
                        width: parent.width
                        from: 0
                        to: 100
                        target: eq.v[band.modelData[0]]
                        Accessible.name: band.modelData[1]
                        onCommitted: x => {
                            const n = { low: eq.v.low, mid: eq.v.mid, high: eq.v.high }
                            n[band.modelData[0]] = Math.round(x)
                            eq.send(true, n.low, n.mid, n.high)
                        }
                    }
                }
            }
        }
    }

    Section {
        id: calls
        title: qsTr("Calls")
        readonly property string mode: Store.pref("callMic", "computer")
        footer: mode === "airpods"
            ? qsTr("Earbuds stay at music quality and their microphone comes over a separate channel. If your app uses another microphone, pick the one ending in \"(Pinna)\". Experimental.")
            : mode === "hfp"
            ? qsTr("When the microphone opens, the earbuds switch to the phone profile and music drops to phone quality too. Takes effect the next time they connect.")
            : qsTr("Earbuds stay at music quality and the computer's microphone is used.")
        Setting {
            title: qsTr("Microphone in calls")
            enabled: Backend.daemon
            Dropdown {
                readonly property var modes: ["computer", "airpods", "hfp"]
                model: [qsTr("This computer's"), qsTr("AirPods, high quality"), qsTr("AirPods, phone quality")]
                currentIndex: Math.max(0, modes.indexOf(calls.mode))
                onPicked: i => Backend.setPref("callMic", modes[i])
            }
        }
        Setting {
            title: qsTr("Current quality")
            enabled: Store.live && !!a.available
            subtitle: a.profile === "hfp"
                ? qsTr("Earbuds and microphone %1, phone quality").arg(a.codec || "HFP")
                : calls.mode === "airpods"
                ? (a.micActive ? qsTr("Earbuds %1, microphone AAC-ELD 64 kHz, on").arg(a.codec || "A2DP")
                               : qsTr("Earbuds %1, microphone turns on when an app listens").arg(a.codec || "A2DP"))
                : qsTr("Earbuds %1, computer's microphone").arg(a.codec || "A2DP")
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
            title: qsTr("Earbud microphone")
            enabled: Store.live && !!a.available
            Segmented {
                options: [qsTr("Off"), qsTr("On")]
                current: a.profile === "hfp" ? 1 : 0
                onPicked: i => Backend.setAudio("profile", i ? "hfp" : "a2dp")
            }
        }
    }

    Section {
        Setting {
            // only offered when PipeWire has more than one; Automatic never touches the profile
            visible: (a.codecs || []).length > 1 || Store.pref("codec", "") !== ""
            title: qsTr("Music codec")
            subtitle: Store.pref("codec", "") === "" ? qsTr("PipeWire picks the best one, %1 on these headphones.").arg((a.codecs || [])[0] || "AAC")
                                                    : qsTr("Switched to on every connection. Switching drops the sound for a moment.")
            enabled: Store.live && !!a.available
            Dropdown {
                readonly property var codes: [""].concat(a.codecs || [])
                model: [qsTr("Automatic")].concat(a.codecs || [])
                currentIndex: Math.max(0, codes.indexOf(Store.pref("codec", "")))
                onPicked: i => Backend.setPref("codec", codes[i])
            }
        }
        Setting {
            id: output
            readonly property int pick: !Store.pref("autoOutput", true) ? 2 : Store.pref("outputOnEar", false) ? 1 : 0
            title: qsTr("Use for system sound")
            subtitle: [qsTr("System audio is routed to the headphones when they connect."),
                       qsTr("System audio moves to the headphones when you put one in, not while they sit in the open case."),
                       qsTr("Pick the output yourself in the system sound settings.")][output.pick]
            enabled: Backend.daemon
            Dropdown {
                model: [qsTr("When connected"), qsTr("When worn"), qsTr("Never")]
                currentIndex: output.pick
                onPicked: i => {
                    Backend.setPref("autoOutput", i !== 2)
                    if (i !== 2) Backend.setPref("outputOnEar", i === 1)
                }
            }
        }
    }

    Section {
        title: qsTr("Smart Audio")
        Setting {
            visible: Store.has("adaptiveVolume")
            title: qsTr("Personalized volume")
            subtitle: qsTr("Adjusts volume based on your environment and listening habits.")
            enabled: Store.ready
            Switch {
                checked: Store.setting("adaptiveVolume", false)
                onToggled: v => Backend.setSetting("adaptiveVolume", v)
            }
        }
        Setting {
            title: qsTr("Lower computer volume while you speak")
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
                Text { text: qsTr("Volume while lowered"); font: Theme.body; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
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
        title: qsTr("Case Speaker")
        visible: Store.has("chimeVolume")
        enabled: Store.ready
        Block {
            Text { text: qsTr("Volume of the case chimes"); font: Theme.body; color: Theme.text }
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
