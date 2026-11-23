import QtQuick
import Pinna

// Sayfanın tepesi: kulaklık görseli ve Apple'daki gibi altında ince pil halkaları.
Column {
    id: root
    readonly property var s: Store.s
    readonly property var bat: s.battery || ({})
    readonly property var ear: s.ear || ({})

    width: parent ? parent.width : 0
    spacing: 10

    function lvl(k) { const c = bat[k]; return c && c.level !== undefined ? c.level : null }
    function chg(k) { return !!(bat[k] && bat[k].charging) }
    // iki tekin pili yakınsa Apple tek halka gösterir; düşük olanı
    readonly property bool joined: lvl("left") !== null && lvl("right") !== null
        && Math.abs(lvl("left") - lvl("right")) <= 5 && chg("left") === chg("right")

    function earText() {
        const l = ear.left, r = ear.right
        if (!Store.ready) return "Kulaklıkla bağlantı kuruluyor…"
        if (l === "ear" && r === "ear") return "Kulaklarında"
        if (l === "ear") return "Sol AirPod kulağında"
        if (r === "ear") return "Sağ AirPod kulağında"
        if (l === "case" && r === "case") return "Kutuda"
        return "Bağlı"
    }

    // Apple'daki gibi: solda kulaklıklar, sağda kutu, her birinin altında halkası
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 18

        Column {
            spacing: 6
            PodArt {
                anchors.horizontalCenter: parent.horizontalCenter
                scaleFactor: 0.62
                leftActive: root.ear.left !== "case"
                rightActive: root.ear.right !== "case"
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 26
                BatteryRing {
                    visible: root.joined
                    label: "AirPods"
                    level: root.joined ? Math.min(root.lvl("left"), root.lvl("right")) : null
                    charging: root.chg("left")
                }
                BatteryRing {
                    visible: !root.joined
                    label: "Sol"
                    level: root.lvl("left")
                    charging: root.chg("left")
                }
                BatteryRing {
                    visible: !root.joined
                    label: "Sağ"
                    level: root.lvl("right")
                    charging: root.chg("right")
                    delay: 60
                }
            }
        }

        Column {
            spacing: 6
            Item {
                width: 150
                height: 106
                Image {
                    anchors.centerIn: parent
                    source: "../assets/case.png"
                    width: 128
                    height: 100
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    opacity: root.lvl("case") !== null ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                }
            }
            BatteryRing {
                anchors.horizontalCenter: parent.horizontalCenter
                label: "Kutu"
                level: root.lvl("case")
                charging: root.chg("case")
                delay: 120
            }
        }
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
}
