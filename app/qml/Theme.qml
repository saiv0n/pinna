pragma Singleton
import QtQuick

// Renkler iOS'un sistem renklerine yakın tutuldu.
QtObject {
    // sistem rengi bilinmiyorsa koyu başla; Hyprland'de çoğu zaman bilinmiyor
    readonly property string forced: typeof pinnaTheme === "string" ? pinnaTheme : ""
    readonly property bool dark: forced === "dark" || (forced !== "light" && Qt.styleHints.colorScheme !== Qt.ColorScheme.Light)
    // masaüstünde animasyonlar kapatıldıysa hareket yerine kısa geçiş
    readonly property bool reduce: typeof pinnaReduceMotion === "boolean" && pinnaReduceMotion

    readonly property color bg: dark ? "#000000" : "#f2f2f7"
    readonly property color bar: dark ? "#ee121212" : "#eef7f7f9"
    readonly property color group: dark ? "#1c1c1e" : "#ffffff"
    readonly property color groupPress: dark ? "#2c2c2e" : "#e5e5ea"
    readonly property color groupHover: dark ? "#232325" : "#f7f7f9"
    readonly property color separator: dark ? "#38383a" : "#d8d8dc"
    readonly property color text: dark ? "#ffffff" : "#000000"
    readonly property color text2: dark ? "#98989f" : "#8a8a8e"
    readonly property color text3: dark ? "#5b5b60" : "#c4c4c7"
    readonly property color header: dark ? "#8d8d93" : "#6d6d72"
    readonly property color accent: dark ? "#0a84ff" : "#007aff"
    readonly property color accentText: "#ffffff"
    readonly property color green: dark ? "#30d158" : "#34c759"
    readonly property color red: dark ? "#ff453a" : "#ff3b30"
    readonly property color orange: dark ? "#ff9f0a" : "#ff9500"
    readonly property color track: dark ? "#39393d" : "#e9e9ea"
    readonly property color sliderTrack: dark ? "#3a3a3c" : "#e5e5ea"
    readonly property color fill: dark ? "#2c2c2e" : "#eeeeef"
    readonly property color segment: dark ? "#2c2c2f" : "#eeeeef"
    readonly property color thumb: dark ? "#636366" : "#ffffff"
    readonly property color focus: Qt.alpha(accent, 0.5)

    readonly property int radius: 12
    readonly property int rowHeight: 46
    readonly property int pad: 16
    readonly property int margin: 18

    // yaylar: hafif taşma, abartısız
    readonly property real springK: 4.2
    readonly property real springD: 0.42
    readonly property int fast: reduce ? 0 : 160
    readonly property int medium: reduce ? 0 : 280
    readonly property int fade: 140

    readonly property font caption: Qt.font({ pixelSize: 12, weight: 400 })
    readonly property font footnote: Qt.font({ pixelSize: 13, weight: 400 })
    readonly property font body: Qt.font({ pixelSize: 15, weight: 400 })
    readonly property font label: Qt.font({ pixelSize: 15, weight: 600 })
    readonly property font section: Qt.font({ pixelSize: 12, weight: 400, letterSpacing: 0.2 })
    readonly property font navTitle: Qt.font({ pixelSize: 16, weight: 600 })
    readonly property font title: Qt.font({ pixelSize: 24, weight: 680 })
}
