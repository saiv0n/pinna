import QtQuick
import Earshot

Column {
    id: root
    property var s: ({})
    signal renameRequested(string name)

    width: parent ? parent.width : 0
    spacing: 14

    readonly property var bat: s.battery || ({})
    readonly property var ear: s.ear || ({})

    function earText() {
        const l = ear.left, r = ear.right
        if (l === "ear" && r === "ear") return "Kulaklarında"
        if (l === "ear") return "Sol AirPod kulağında"
        if (r === "ear") return "Sağ AirPod kulağında"
        if (l === "case" && r === "case") return "Kutuda"
        return "Bağlı"
    }

    PodArt {
        anchors.horizontalCenter: parent.horizontalCenter
        leftActive: root.ear.left !== "case"
        rightActive: root.ear.right !== "case"
    }

    Column {
        width: parent.width
        spacing: 3

        Item {
            width: parent.width
            height: nameText.height

            Text {
                id: nameText
                visible: !nameEdit.visible
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.s.name || "AirPods"
                font: Theme.title
                color: Theme.text
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        nameEdit.text = nameText.text
                        nameEdit.visible = true
                        nameEdit.forceActiveFocus()
                        nameEdit.selectAll()
                    }
                }
            }

            TextInput {
                id: nameEdit
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(140, contentWidth + 8)
                horizontalAlignment: TextInput.AlignHCenter
                font: Theme.title
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                maximumLength: 32
                onAccepted: {
                    visible = false
                    if (text.trim().length && text !== root.s.name)
                        root.renameRequested(text.trim())
                }
                Keys.onEscapePressed: visible = false
                onActiveFocusChanged: if (!activeFocus) visible = false

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.bottom
                    height: 2
                    radius: 1
                    color: Theme.accent
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (root.s.modelName || "AirPods") + "  ·  " + root.earText()
            font: Theme.caption
            color: Theme.text2
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 22
        BatteryRing {
            label: "Sol"
            level: root.bat.left ? root.bat.left.level : null
            charging: root.bat.left ? root.bat.left.charging : false
        }
        BatteryRing {
            label: "Sağ"
            level: root.bat.right ? root.bat.right.level : null
            charging: root.bat.right ? root.bat.right.charging : false
        }
        BatteryRing {
            label: "Kutu"
            level: root.bat["case"] ? root.bat["case"].level : null
            charging: root.bat["case"] ? root.bat["case"].charging : false
        }
    }
}
