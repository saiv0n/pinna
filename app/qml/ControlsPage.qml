import QtQuick
import Pinna

Page {
    id: page
    title: qsTr("Controls")
    // do not leave the stream on and drain the battery when the window closes
    Component.onDestruction: if (Store.s.headTracking) Backend.headTracking(false)

    Section {
        title: qsTr("Press and Hold")
        enabled: Store.ready
        Repeater {
            model: [["holdLeft", qsTr("Left AirPod")], ["holdRight", qsTr("Right AirPod")]]
            Setting {
                required property var modelData
                title: modelData[1]
                Dropdown {
                    model: [qsTr("Noise control"), qsTr("Voice assistant")]
                    currentIndex: Store.setting(parent.parent.modelData[0], 1) === 5 ? 1 : 0
                    onPicked: i => Backend.setSetting(parent.parent.modelData[0], i === 1 ? 5 : 1)
                }
            }
        }
        Setting {
            visible: Store.has("pressSpeed")
            title: qsTr("Press speed")
            subtitle: qsTr("How much time can pass between presses for a double or triple press.")
            Segmented {
                options: [qsTr("Default"), qsTr("Slower"), qsTr("Slowest")]
                current: Store.setting("pressSpeed", 0)
                onPicked: i => Backend.setSetting("pressSpeed", i)
            }
        }
        Setting {
            visible: Store.has("holdDuration")
            title: qsTr("Press and hold duration")
            Segmented {
                options: [qsTr("Default"), qsTr("Shorter"), qsTr("Shortest")]
                current: Store.setting("holdDuration", 0)
                onPicked: i => Backend.setSetting("holdDuration", i)
            }
        }
    }

    // marked presses are forwarded to us instead of handled by the buds, so they can do anything here
    Section {
        id: press
        title: qsTr("Press Shortcuts")
        experimental: true
        footer: qsTr("Bind presses to actions on this computer. Unassigned presses work as usual.")
        enabled: Store.ready
        property string side: "left"
        // the two-mode toggles let each bud flip between its own pair (LibrePods #905)
        readonly property var actions: ["", "playPause", "next", "previous", "volumeUp", "volumeDown", "micMute", "mode", "ancTransparency",
            "toggle:anc+adaptive", "toggle:transparency+adaptive", "toggle:anc+off", "nothing", "cmd"]
        readonly property var names: [qsTr("Play / Pause"), qsTr("Next track"), qsTr("Previous track"), qsTr("Volume up"),
            qsTr("Volume down"), qsTr("Mute microphone"), qsTr("Change listening mode"), qsTr("Noise Cancellation / Transparency"),
            qsTr("Noise Cancellation / Adaptive"), qsTr("Transparency / Adaptive"), qsTr("Noise Cancellation / Off"), qsTr("Nothing"), qsTr("Run command…")]
        readonly property int cmdIndex: actions.length - 1
        function value(slot) {
            const k = "stem." + slot
            const v = Store.prefs[k]
            return v !== undefined ? v : ((Store.prefs.stem || {})[slot] || "")
        }
        Setting {
            title: qsTr("Headphones")
            Segmented {
                options: [qsTr("Left"), qsTr("Right")]
                current: press.side === "left" ? 0 : 1
                onPicked: i => press.side = i === 0 ? "left" : "right"
            }
        }
        Repeater {
            model: [["double", qsTr("Double press"), qsTr("Default: next track")],
                    ["triple", qsTr("Triple press"), qsTr("Default: previous track")],
                    ["long", qsTr("Press and hold"), qsTr("Default: setting above")]]
            Setting {
                id: row
                required property var modelData
                readonly property string slot: modelData[0] + "." + press.side
                readonly property string cur: press.value(slot)
                readonly property bool isCmd: cur.startsWith("cmd:") || picker.currentIndex === press.cmdIndex
                title: modelData[1]
                subtitle: cur === "" ? modelData[2] : ""
                Field {
                    id: cmd
                    visible: row.isCmd
                    width: 180
                    placeholderText: qsTr("e.g. grim ~/shot.png")
                    text: row.cur.startsWith("cmd:") ? row.cur.slice(4) : ""
                    Accessible.name: qsTr("Command")
                    onAccepted: { if (text.trim()) Backend.setPref("stem." + row.slot, "cmd:" + text.trim()); focus = false }
                }
                Dropdown {
                    id: picker
                    model: [qsTr("Default")].concat(press.names)
                    currentIndex: row.cur.startsWith("cmd:") ? press.cmdIndex : Math.max(0, press.actions.indexOf(row.cur))
                    Accessible.name: row.title
                    onPicked: i => {
                        if (i === press.cmdIndex) { cmd.forceActiveFocus(); return }
                        Backend.setPref("stem." + row.slot, press.actions[i])
                    }
                }
            }
        }
    }

    // runs off the head tracking stream, so it stays on while this is enabled
    Section {
        id: gestures
        title: qsTr("Head Gestures")
        visible: Store.headSensor
        experimental: true
        enabled: Store.ready
        readonly property bool on: Store.pref("headGestures", false)
        footer: qsTr("Nod or shake your head a few times to run an action. Keeps the motion sensor on, which uses a bit more battery.")
        Setting {
            title: qsTr("Head gestures")
            Switch { checked: gestures.on; onToggled: v => Backend.setPref("headGestures", v) }
        }
        Repeater {
            model: [["gestureNod", qsTr("Nod"), "playPause"], ["gestureShake", qsTr("Shake"), "next"]]
            Setting {
                id: grow
                required property var modelData
                visible: gestures.on
                readonly property string cur: Store.pref(modelData[0], modelData[2])
                readonly property bool isCmd: cur.startsWith("cmd:") || gpick.currentIndex === press.cmdIndex - 1
                title: modelData[1]
                Field {
                    id: gcmd
                    visible: grow.isCmd
                    width: 180
                    placeholderText: qsTr("e.g. grim ~/shot.png")
                    text: grow.cur.startsWith("cmd:") ? grow.cur.slice(4) : ""
                    Accessible.name: qsTr("Command")
                    onAccepted: { if (text.trim()) Backend.setPref(grow.modelData[0], "cmd:" + text.trim()); focus = false }
                }
                Dropdown {
                    id: gpick
                    model: press.names
                    currentIndex: grow.cur.startsWith("cmd:") ? press.cmdIndex - 1 : Math.max(0, press.actions.indexOf(grow.cur) - 1)
                    Accessible.name: grow.title
                    onPicked: i => {
                        if (i === press.cmdIndex - 1) { gcmd.forceActiveFocus(); return }
                        Backend.setPref(grow.modelData[0], press.actions[i + 1])
                    }
                }
            }
        }
    }

    Section {
        title: qsTr("Volume Swipe")
        visible: Store.has("volumeSwipe")
        enabled: Store.ready
        Setting {
            title: qsTr("Swipe on stem to change volume")
            Switch {
                checked: Store.setting("volumeSwipe", true)
                onToggled: v => Backend.setSetting("volumeSwipe", v)
            }
        }
        Setting {
            title: qsTr("Swipe length")
            enabled: Store.setting("volumeSwipe", true)
            Segmented {
                options: [qsTr("Default"), qsTr("Longer"), qsTr("Longest")]
                current: Store.setting("volumeSwipeInterval", 0)
                onPicked: i => Backend.setSetting("volumeSwipeInterval", i)
            }
        }
    }

    Section {
        title: qsTr("Head Tracking")
        visible: Store.headSensor
        footer: qsTr("Shows the direction of your head live using the headphones' motion sensor. Uses a bit more battery while on.")
        enabled: Store.ready
        Setting {
            id: head
            readonly property bool on: !!Store.s.headTracking
            title: qsTr("Live view")
            subtitle: on && !Backend.head.length ? qsTr("Waiting for data from the headphones…") : ""
            Switch { checked: head.on; onToggled: v => Backend.headTracking(v) }
        }
        Block {
            visible: head.on
            HeadView { width: parent.width }
        }
    }
}
