import QtQuick
import Pinna

// Sayfanın tepesi: kulaklık görseli, ad, durum ve piller.
Column {
    id: root
    readonly property var s: Store.s
    readonly property var bat: s.battery || ({})
    readonly property var ear: s.ear || ({})
    readonly property alias nameItem: nameText

    width: parent ? parent.width : 0
    spacing: 4

    function earText() {
        const l = ear.left, r = ear.right
        if (!Store.ready) return "Kulaklıkla bağlantı kuruluyor…"
        if (l === "ear" && r === "ear") return "Kulaklarında"
        if (l === "ear") return "Sol AirPod kulağında"
        if (r === "ear") return "Sağ AirPod kulağında"
        if (l === "case" && r === "case") return "Kutuda"
        return "Bağlı"
    }
    function cell(k) { return bat[k] || ({}) }

    PodArt {
        anchors.horizontalCenter: parent.horizontalCenter
        scaleFactor: 0.92
        leftActive: root.ear.left !== "case"
        rightActive: root.ear.right !== "case"
    }

    Item { width: 1; height: 6 }

    Text {
        id: nameText
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Store.name
        font: Theme.title
        color: Theme.text
        elide: Text.ElideRight
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Spinner {
            visible: !Store.ready
            size: 13
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.earText()
            font: Theme.footnote
            color: Theme.text2
        }
    }

    Item { width: 1; height: 14 }

    Row {
        id: batteries
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 30

        Repeater {
            model: [
                { key: "left", label: "Sol" },
                { key: "right", label: "Sağ" },
                { key: "case", label: "Kutu" }
            ]
            Column {
                required property var modelData
                readonly property var c: root.cell(modelData.key)
                // kutunun pili bilinmiyorsa Apple gibi hiç gösterme
                visible: modelData.key !== "case" || (c.level !== null && c.level !== undefined)
                spacing: 4
                BatteryGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    level: parent.c.level === undefined ? null : parent.c.level
                    charging: !!parent.c.charging
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData.label
                    font: Theme.caption
                    color: Theme.text2
                }
            }
        }
    }
}
