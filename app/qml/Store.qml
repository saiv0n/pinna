pragma Singleton
import QtQuick

// Shortcuts into the service state so pages do not parse the same thing again and again.
QtObject {
    readonly property var s: Backend.state
    readonly property var settings: s.settings || ({})
    readonly property var prefs: s.prefs || ({})
    readonly property var battery: s.battery || ({})
    readonly property var audio: s.audio || ({})
    readonly property var devices: s.devices || []
    readonly property bool live: Backend.daemon && !!s.connected
    readonly property bool ready: live && s.ready !== false
    readonly property string name: s.name || "AirPods"

    function setting(key, fallback) {
        return settings[key] !== undefined && settings[key] !== null ? settings[key] : fallback
    }
    function pref(key, fallback) {
        return prefs[key] !== undefined ? prefs[key] : fallback
    }
    function level(k) {
        const c = battery[k]
        return c && c.level !== null && c.level !== undefined ? c.level : null
    }
    function charging(k) { return !!(battery[k] && battery[k].charging) }

    // last known values from the battery history, shown when the case is closed or the buds are away
    readonly property var history: Backend.history || []
    function lastKnown(i) {
        for (let n = history.length - 1; n >= 0; n--)
            if (history[n][i] >= 0) return { level: history[n][i], at: history[n][0] }
        return null
    }
    readonly property var lastCase: lastKnown(3)
    readonly property var lastSeen: history.length ? history[history.length - 1] : null
    function ago(t) {
        const m = Math.max(0, Math.round((Date.now() / 1000 - t) / 60))
        return m < 2 ? qsTr("just now") : m < 60 ? qsTr("%1 min ago").arg(m)
            : m < 1440 ? qsTr("%1 h ago").arg(Math.round(m / 60)) : qsTr("%1 d ago").arg(Math.round(m / 1440))
    }

    readonly property var modeNames: ({
        off: qsTr("Off"),
        transparency: qsTr("Transparency"),
        adaptive: qsTr("Adaptive"),
        anc: qsTr("Noise Cancellation")
    })
    readonly property var cycleBits: [
        { bit: 1, key: "off" },
        { bit: 4, key: "transparency" },
        { bit: 8, key: "adaptive" },
        { bit: 2, key: "anc" }
    ]
}
