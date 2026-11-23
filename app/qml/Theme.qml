pragma Singleton
import QtQuick

QtObject {
    // sistem rengi bilinmiyorsa koyu başla; Hyprland'de çoğu zaman bilinmiyor
    // PINNA_THEME=light|dark ile zorlanabilir
    readonly property string forced: typeof pinnaTheme === "string" ? pinnaTheme : ""
    readonly property bool dark: forced === "dark" || (forced !== "light" && Qt.styleHints.colorScheme !== Qt.ColorScheme.Light)

    readonly property color bg: dark ? "#111317" : "#f2f2f6"
    readonly property color bgTop: dark ? "#171a20" : "#f7f7fa"
    readonly property color group: dark ? "#1b1e23" : "#ffffff"
    readonly property color groupHover: dark ? "#22262c" : "#f4f4f7"
    readonly property color groupPress: dark ? "#292d34" : "#ebebf0"
    readonly property color separator: dark ? "#2a2e35" : "#e4e4ea"
    readonly property color text: dark ? "#f3f4f6" : "#111215"
    readonly property color text2: dark ? "#9ba0a9" : "#6b6e76"
    readonly property color text3: dark ? "#6c7079" : "#9a9ca4"
    readonly property color accent: dark ? "#3d8ef7" : "#0a72ef"
    readonly property color accentText: "#ffffff"
    readonly property color green: dark ? "#3fcf72" : "#22a653"
    readonly property color red: dark ? "#ff5d55" : "#e5372d"
    // anahtarlar iOS'taki gibi yeşil, seçimler mavi
    readonly property color switchOn: dark ? "#32d35d" : "#34c759"
    readonly property color track: dark ? "#3a3e46" : "#e3e3e8"
    readonly property color segment: dark ? "#25282e" : "#e9e9ee"
    readonly property color thumb: dark ? "#454a53" : "#ffffff"
    readonly property color focus: Qt.alpha(accent, 0.55)

    readonly property int radius: 12
    readonly property int radiusSmall: 8
    readonly property int rowHeight: 48
    readonly property int pad: 16

    readonly property int fast: 160
    readonly property int medium: 220
    readonly property int slow: 900

    readonly property font caption: Qt.font({ pixelSize: 12, weight: 450 })
    readonly property font body: Qt.font({ pixelSize: 14, weight: 400 })
    readonly property font label: Qt.font({ pixelSize: 14, weight: 500 })
    readonly property font section: Qt.font({ pixelSize: 13, weight: 500 })
    readonly property font title: Qt.font({ pixelSize: 22, weight: 640 })
    readonly property font big: Qt.font({ pixelSize: 28, weight: 650 })
}
