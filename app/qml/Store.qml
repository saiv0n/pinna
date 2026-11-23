pragma Singleton
import QtQuick

// Servis durumuna kısa yollar; sayfalar aynı şeyi tekrar tekrar ayıklamasın.
QtObject {
    readonly property var s: Backend.state
    readonly property var settings: s.settings || ({})
    readonly property var prefs: s.prefs || ({})
    readonly property bool loaded: Backend.daemon && s.connected !== undefined
    readonly property bool live: Backend.daemon && !!s.connected
    readonly property bool ready: live && s.ready !== false
    readonly property string name: s.name || "AirPods"

    function setting(key, fallback) {
        return settings[key] !== undefined && settings[key] !== null ? settings[key] : fallback
    }
    function pref(key, fallback) {
        return prefs[key] !== undefined ? prefs[key] : fallback
    }

    readonly property var modeNames: ({
        off: "Kapalı",
        transparency: "Şeffaflık",
        adaptive: "Uyarlanabilir",
        anc: "Gürültü Engelleme"
    })
    readonly property var cycleBits: [
        { bit: 1, key: "off" },
        { bit: 4, key: "transparency" },
        { bit: 8, key: "adaptive" },
        { bit: 2, key: "anc" }
    ]
}
