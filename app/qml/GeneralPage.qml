import QtQuick
import Pinna

Page {
    id: page
    property Item confirm
    title: qsTr("General")
    function startPairing() { Backend.discover(true) }

    // battery summary
    Section {
        Block {
            Row {
                width: parent.width
                Repeater {
                    model: [["left", qsTr("Left AirPod"), 1], ["right", qsTr("Right AirPod"), 2], ["case", qsTr("Case"), 3]]
                    Item {
                        id: cell
                        required property var modelData
                        readonly property var now: Store.level(modelData[0])
                        readonly property var last: now === null ? Store.lastKnown(modelData[2]) : null
                        readonly property var lvl: now !== null ? now : last ? last.level : null
                        readonly property string ear: modelData[0] === "case" ? "" : ((Store.s.ear || {})[modelData[0]] || "")
                        width: parent.width / 3
                        height: 84
                        opacity: cell.last ? 0.6 : 1
                        Accessible.role: Accessible.StaticText
                        Accessible.name: label.text + ", " + sub.text
                        BatteryRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 44
                            stroke: 3.5
                            level: cell.lvl
                            charging: cell.now !== null && Store.charging(cell.modelData[0])
                        }
                        Text {
                            id: label
                            y: 50
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData[1] + (cell.lvl !== null ? "  " + cell.lvl + "%" : "")
                            font: Theme.label
                            color: cell.lvl !== null ? Theme.text : Theme.text3
                        }
                        Text {
                            id: sub
                            y: 68
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property var est: (Store.s.estimate || {})[cell.modelData[0]]
                            readonly property bool charging: cell.now !== null && Store.charging(cell.modelData[0])
                            text: charging ? (est ? qsTr("Full in %1").arg(Store.duration(est)) : qsTr("Charging"))
                                : est && cell.ear === "ear" ? qsTr("%1 left").arg(Store.duration(est))
                                : cell.last ? qsTr("Last known, %1").arg(Store.ago(cell.last.at))
                                : cell.lvl === null ? (cell.modelData[0] === "case" ? qsTr("Open the case") : qsTr("Unknown"))
                                : cell.ear === "ear" ? qsTr("In ear") : cell.ear === "case" ? qsTr("In case") : cell.ear === "out" ? qsTr("Out of ear") : ""
                            font: Theme.footnote
                            color: Theme.text2
                        }
                    }
                }
            }
        }
    }

    // hot and cold with the BLE advert strength while disconnected
    Section {
        id: finder
        title: qsTr("Find Your Headphones")
        visible: Backend.daemon && !Store.live && (Store.devices.length > 0 || !!Store.s.address)
        footer: qsTr("Walk around with the computer; more bars means you are getting closer. A closed case advertises less often.")
        property real now: Date.now() / 1000
        Timer { interval: 2000; repeat: true; running: finder.visible; onTriggered: finder.now = Date.now() / 1000 }
        readonly property bool fresh: Store.s.signal !== null && Store.s.signal !== undefined && finder.now - (Store.s.signalAt || 0) < 30
        readonly property int bars: !fresh ? 0 : Store.s.signal > -55 ? 4 : Store.s.signal > -67 ? 3 : Store.s.signal > -80 ? 2 : 1
        Setting {
            title: !Store.pref("caseScan", true) ? qsTr("Scanning is off")
                : !finder.fresh ? qsTr("Looking for a signal…")
                : [qsTr("Very far"), qsTr("Far"), qsTr("Nearby"), qsTr("Very close")][finder.bars - 1]
            subtitle: finder.fresh ? qsTr("%1 dBm, %2").arg(Store.s.signal).arg(Store.ago(Store.s.signalAt))
                : Store.pref("caseScan", true) ? qsTr("Open the case lid or take out an AirPod.") : ""
            Row {
                visible: Store.pref("caseScan", true)
                spacing: 3
                Accessible.role: Accessible.Indicator
                Accessible.name: qsTr("Signal %1 of 4").arg(finder.bars)
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 5
                        height: 6 + index * 4
                        radius: 1.5
                        anchors.bottom: parent.bottom
                        color: index < finder.bars ? Theme.accent : Theme.control
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }
                }
            }
            Button {
                visible: !Store.pref("caseScan", true)
                text: qsTr("Turn On Scanning")
                onClicked: Backend.setPref("caseScan", true)
            }
        }
    }

    Section {
        title: qsTr("Headphones")
        Setting {
            title: qsTr("Name")
            enabled: Store.ready
            Field {
                id: nameField
                width: 220
                text: Store.name
                maximumLength: 32
                onAccepted: { if (text.trim() && text !== Store.name) Backend.rename(text.trim()); focus = false }
                onActiveFocusChanged: if (!activeFocus) text = Qt.binding(() => Store.name)
            }
        }
        Setting {
            title: qsTr("Connect Automatically")
            subtitle: qsTr("The headphones can switch to this computer from nearby devices on their own.")
            enabled: Store.ready
            Switch {
                checked: Store.setting("autoConnect", true)
                onToggled: v => Backend.setSetting("autoConnect", v)
            }
        }
        Setting {
            title: qsTr("Connection")
            subtitle: Store.live ? qsTr("Connected to this computer") : qsTr("Not connected")
            enabled: Backend.daemon
            Button {
                text: Store.live ? qsTr("Disconnect") : qsTr("Connect")
                onClicked: Store.live ? Backend.disconnectDevice() : Backend.connectDevice()
            }
        }
    }

    Section {
        title: qsTr("Battery History")
        Block {
            BatteryChart { width: parent.width }
        }
    }

    Section {
        title: qsTr("Paired Headphones")
        footer: Store.s.discovering ? qsTr("Open the case lid and hold the button on the back until the light flashes white.") : ""
        Repeater {
            model: Store.devices
            Setting {
                id: dev
                required property var modelData
                readonly property bool current: modelData.address === Store.s.address
                title: modelData.name + (current ? "  ·  " + qsTr("selected") : "")
                subtitle: (modelData.modelName || "") + (modelData.connected ? "  ·  " + qsTr("connected") : "")
                onMenu: devMenu.popup()
                Button {
                    visible: !dev.current || !dev.modelData.connected
                    text: dev.current ? qsTr("Connect") : qsTr("Switch to These")
                    onClicked: Backend.select(dev.modelData.address)
                }
                Button {
                    text: qsTr("Forget")
                    destructive: true
                    onClicked: page.confirm.ask(qsTr("Forget %1?").arg(dev.modelData.name),
                        qsTr("The pairing is removed from this computer. You'll need to pair again to use them."),
                        "", qsTr("Forget"), () => Backend.forget(dev.modelData.address))
                }
                Menu {
                    id: devMenu
                    MenuItemLike { text: qsTr("Copy Address"); onTriggered: Backend.copy(dev.modelData.address) }
                    MenuItemLike { text: qsTr("Forget…"); onTriggered: Backend.forget(dev.modelData.address) }
                }
            }
        }
        Repeater {
            model: Store.s.nearby || []
            Setting {
                required property var modelData
                title: modelData.name || modelData.address
                subtitle: qsTr("Ready to pair")
                Button { primary: true; text: qsTr("Pair"); onClicked: Backend.pair(parent.parent.modelData.address) }
            }
        }
        Setting {
            title: Store.s.discovering ? qsTr("Searching…") : qsTr("Pair new headphones")
            enabled: Backend.daemon
            Spinner { visible: !!Store.s.discovering; size: 14 }
            Button {
                text: Store.s.discovering ? qsTr("Stop") : qsTr("Search")
                onClicked: Backend.discover(!Store.s.discovering)
            }
        }
    }
}
