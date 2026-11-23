pragma Singleton
import QtQuick

// Masaüstü belirteçleri. Renkler nötr gri, tek vurgu rengi mavi.
QtObject {
    readonly property string forced: typeof pinnaTheme === "string" ? pinnaTheme : ""
    readonly property bool dark: forced === "dark" || (forced !== "light" && Qt.styleHints.colorScheme !== Qt.ColorScheme.Light)
    readonly property bool reduce: typeof pinnaReduceMotion === "boolean" && pinnaReduceMotion

    readonly property color bg: dark ? "#1c1c1f" : "#f5f5f6"
    readonly property color sidebar: dark ? "#161618" : "#ebebed"
    readonly property color card: dark ? "#252528" : "#ffffff"
    readonly property color border: dark ? "#33ffffff" : "#1a000000"
    readonly property color line: dark ? "#14ffffff" : "#0f000000"
    readonly property color hover: dark ? "#0fffffff" : "#0a000000"
    readonly property color press: dark ? "#1affffff" : "#14000000"
    readonly property color selected: dark ? "#2e2e33" : "#dcdce0"
    readonly property color text: dark ? "#f2f2f4" : "#1d1d1f"
    readonly property color text2: dark ? "#a3a3aa" : "#6b6b72"
    readonly property color text3: dark ? "#6c6c74" : "#a2a2a8"
    readonly property color accent: dark ? "#4c8dff" : "#2f6fe4"
    readonly property color accentText: "#ffffff"
    readonly property color green: dark ? "#3ccf6e" : "#22a356"
    readonly property color red: dark ? "#ff6b61" : "#d93a30"
    readonly property color orange: dark ? "#f5a623" : "#d98200"
    readonly property color control: dark ? "#38383d" : "#e4e4e8"
    readonly property color controlHover: dark ? "#424248" : "#d9d9de"
    readonly property color focus: Qt.alpha(accent, 0.55)
    readonly property color shade: dark ? "#80000000" : "#26000000"

    // eski bileşenlerin adları
    readonly property color group: card
    readonly property color groupPress: press
    readonly property color fill: control

    readonly property int radius: 10
    readonly property int small: 6
    readonly property int row: 36
    readonly property int pad: 14

    readonly property int fast: reduce ? 0 : 120
    readonly property int medium: reduce ? 0 : 200

    readonly property string family: "Inter Variable"
    readonly property font caption: Qt.font({ family: family, pixelSize: 11, weight: 400 })
    readonly property font footnote: Qt.font({ family: family, pixelSize: 12, weight: 400 })
    readonly property font body: Qt.font({ family: family, pixelSize: 13, weight: 400 })
    readonly property font label: Qt.font({ family: family, pixelSize: 13, weight: 600 })
    readonly property font heading: Qt.font({ family: family, pixelSize: 12, weight: 600 })
    readonly property font title: Qt.font({ family: family, pixelSize: 20, weight: 650, letterSpacing: -0.3 })
    readonly property font big: Qt.font({ family: family, pixelSize: 26, weight: 650, letterSpacing: -0.5 })
}
