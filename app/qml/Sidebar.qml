import QtQuick
import QtQuick.Effects
import Pinna

// Solda cihaz kartı, bölümler ve servis durumu.
Rectangle {
    id: root
    property int current: 0
    property var pages: []
    signal picked(int index)
    signal pair()
    color: Theme.sidebar
    readonly property bool paired: Store.devices.length > 0 || !!Store.s.address
    width: 236

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

    // cihaz kartı: görsel, tam ad, durum ve üç pil
    readonly property bool hasLevels: Store.level("left") !== null || Store.level("right") !== null
    readonly property string status: !Backend.daemon ? qsTr("Service not running")
        : Store.s.adapter === false ? qsTr("Bluetooth is off")
        : !root.paired ? qsTr("No paired headphones")
        : Store.live ? (Store.modeNames[Store.s.mode] || qsTr("Connected"))
        : Store.lastSeen ? qsTr("Last seen %1").arg(Store.ago(Store.lastSeen[0]))
        : qsTr("Not connected")

    Rectangle {
        id: device
        x: 10
        y: 12
        width: parent.width - 20
        height: card.height + 20
        radius: Theme.radius
        color: cardArea.pressed ? Theme.press : cardArea.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Accessible.role: Accessible.Button
        Accessible.name: Store.name + ", " + root.status
        Accessible.onPressAction: root.picked(0)

        Column {
            id: card
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 12

            Row {
                width: parent.width
                spacing: 10
                Row {
                    id: art
                    spacing: -3
                    opacity: Store.live ? 1 : 0.5
                    Behavior on opacity { NumberAnimation { duration: Theme.medium } }
                    // beyaz kulaklık açık zeminde kaybolmasın
                    layer.enabled: !Theme.dark
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: 0.35
                        shadowBlur: 0.35
                        shadowVerticalOffset: 1
                    }
                    Repeater {
                        model: [false, true]
                        Image {
                            required property bool modelData
                            source: "../assets/bud.png"
                            mirror: modelData
                            width: 22
                            height: 40
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                    }
                }
                Column {
                    width: parent.width - art.width - 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: Store.name
                        font.family: Theme.family
                        font.pixelSize: 14
                        font.weight: 600
                        color: Theme.text
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        lineHeight: 1.1
                    }
                    Row {
                        spacing: 6
                        width: parent.width
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Store.live ? Theme.green : Theme.text3
                        }
                        Text {
                            width: parent.width - 12
                            text: root.status
                            font: Theme.footnote
                            color: Theme.text2
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10
                visible: root.hasLevels || (Store.lastSeen && root.paired && !Store.live)
                Repeater {
                    model: [["left", qsTr("Left"), 1], ["right", qsTr("Right"), 2], ["case", qsTr("Case"), 3]]
                    BatteryTile {
                        id: tile
                        required property var modelData
                        readonly property var now: Store.level(modelData[0])
                        readonly property var last: Store.lastKnown(modelData[2])
                        width: (card.width - 20) / 3
                        name: modelData[1]
                        level: now !== null ? now : last ? last.level : null
                        stale: now === null
                        charging: now !== null && Store.charging(modelData[0])
                    }
                }
            }

            Button {
                visible: Backend.daemon && Store.s.adapter !== false && root.paired && !Store.live
                text: qsTr("Connect")
                onClicked: Backend.connectDevice()
            }
        }

        MouseArea {
            id: cardArea
            z: -1
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? deviceMenu.popup() : root.picked(0)
        }
    }

    Menu {
        id: deviceMenu
        Instantiator {
            model: Store.devices.length > 1 ? Store.devices : []
            delegate: MenuItemLike {
                required property var modelData
                text: (modelData.address === Store.s.address ? "✓ " : "    ") + modelData.name
                onTriggered: Backend.select(modelData.address)
            }
            onObjectAdded: (i, o) => deviceMenu.insertItem(i, o)
            onObjectRemoved: (i, o) => deviceMenu.removeItem(o)
        }
        MenuItemLike {
            text: Store.live ? qsTr("Disconnect") : qsTr("Connect")
            enabled: Backend.daemon
            onTriggered: Store.live ? Backend.disconnectDevice() : Backend.connectDevice()
        }
        MenuItemLike { text: qsTr("Pair New Headphones…"); enabled: Backend.daemon; onTriggered: root.pair() }
        MenuItemLike { text: qsTr("Copy Address"); enabled: !!Store.s.address; onTriggered: Backend.copy(Store.s.address) }
    }

    // bölümler
    ListView {
        id: nav
        x: 10
        y: device.y + device.height + 10
        width: parent.width - 20
        height: contentHeight
        interactive: false
        model: root.pages
        currentIndex: root.current
        keyNavigationEnabled: true
        activeFocusOnTab: true
        Keys.onUpPressed: root.picked(Math.max(0, root.current - 1))
        Keys.onDownPressed: root.picked(Math.min(count - 1, root.current + 1))
        spacing: 2
        delegate: Rectangle {
            id: item
            required property int index
            required property var modelData
            readonly property bool on: index === root.current
            width: ListView.view.width
            height: 30
            radius: Theme.small
            color: on ? Theme.selected : area.containsMouse ? Theme.hover : "transparent"
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: Theme.focus
                visible: nav.activeFocus && item.on
            }
            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: item.modelData
                font.family: Theme.family
                font.pixelSize: 13
                font.weight: item.on ? 600 : 400
                color: Theme.text
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Ctrl+" + (item.index + 1)
                font: Theme.caption
                color: Theme.text3
                visible: area.containsMouse
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.picked(item.index)
            }
        }
    }

    // servis durumu
    Row {
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 7
        Rectangle {
            width: 7
            height: 7
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: Backend.daemon ? Theme.green : Theme.red
        }
        Text {
            text: Backend.daemon ? qsTr("pinnad is running") : qsTr("pinnad is not running")
            font: Theme.footnote
            color: Theme.text2
        }
    }
}
