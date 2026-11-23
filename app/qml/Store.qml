pragma Singleton
import QtQuick

// Servis durumuna kısa yollar; sayfalar aynı şeyi tekrar tekrar ayıklamasın.
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

    readonly property var modeNames: ({
        off: qsTr("Kapalı"),
        transparency: qsTr("Şeffaflık"),
        adaptive: qsTr("Uyarlanabilir"),
        anc: qsTr("Gürültü Engelleme")
    })
    readonly property var cycleBits: [
        { bit: 1, key: "off" },
        { bit: 4, key: "transparency" },
        { bit: 8, key: "adaptive" },
        { bit: 2, key: "anc" }
    ]
}
