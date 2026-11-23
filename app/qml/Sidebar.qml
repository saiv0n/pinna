import QtQuick
import Pinna

// Solda cihaz kartı, bölümler ve servis durumu.
Rectangle {
    id: root
    property int current: 0
    property var pages: []
    signal picked(int index)
    signal pair()
    color: Theme.sidebar
    width: 236

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

    // cihaz kartı
    Rectangle {
        id: device
        x: 12
        y: 14
        width: parent.width - 24
        height: 100
        radius: Theme.radius
        color: cardArea.containsMouse ? Theme.hover : "transparent"

        Row {
            id: art
            x: 6
            y: 10
            spacing: -2
            opacity: Store.live ? 1 : 0.45
            Repeater {
                model: [false, true]
                Image {
                    required property bool modelData
                    source: "../assets/bud.png"
                    mirror: modelData
                    width: 24
                    height: 44
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
        }
        Column {
            x: art.x + art.width + 10
            y: 14
            width: parent.width - x - 28
            spacing: 2
            Text {
                width: parent.width
                text: Store.name
                font: Theme.label
                color: Theme.text
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: !Backend.daemon ? qsTr("Servis çalışmıyor")
                    : Store.live ? (Store.modeNames[Store.s.mode] || qsTr("Bağlı"))
                    : qsTr("Bağlı değil")
                font: Theme.footnote
                color: Store.live ? Theme.text2 : Theme.text3
                elide: Text.ElideRight
            }
        }
        IconButton {
            anchors.right: parent.right
            y: 10
            icon: "more"
            Accessible.name: qsTr("Cihaz menüsü")
            onClicked: deviceMenu.popup(this, 0, height)
        }
        Row {
            x: 8
            y: 66
            spacing: 12
            visible: Store.level("left") !== null || Store.level("right") !== null
            Repeater {
                model: [["left"], ["right"], ["case"]]
                Row {
                    required property var modelData
                    visible: Store.level(modelData[0]) !== null
                    spacing: 4
                    BatteryRing {
                        size: 18
                        stroke: 2
                        level: Store.level(parent.modelData[0])
                        charging: Store.charging(parent.modelData[0])
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Store.level(parent.modelData[0]) + "%"
                        font: Theme.footnote
                        color: Theme.text
                    }
                }
            }
        }
        Button {
            x: 8
            y: 62
            visible: Backend.daemon && !Store.live && Store.level("left") === null
            text: qsTr("Bağlan")
            onClicked: Backend.connectDevice()
        }
        Button {
            x: 8
            y: 62
            visible: !Backend.daemon
            text: qsTr("Servisi Başlat")
            onClicked: Backend.startDaemon()
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
            text: Store.live ? qsTr("Bağlantıyı Kes") : qsTr("Bağlan")
            enabled: Backend.daemon
            onTriggered: Store.live ? Backend.disconnectDevice() : Backend.connectDevice()
        }
        MenuItemLike { text: qsTr("Yeni Kulaklık Eşleştir…"); enabled: Backend.daemon; onTriggered: root.pair() }
        MenuItemLike { text: qsTr("Adresi Kopyala"); enabled: !!Store.s.address; onTriggered: Backend.copy(Store.s.address) }
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
            text: Backend.daemon ? qsTr("pinnad çalışıyor") : qsTr("pinnad çalışmıyor")
            font: Theme.footnote
            color: Theme.text2
        }
    }
}
