import QtQuick
import Pinna

Page {
    id: page
    property Item confirm
    title: qsTr("Genel")
    function startPairing() { Backend.discover(true) }

    // pil özeti
    Section {
        Block {
            Row {
                width: parent.width
                Repeater {
                    model: [["left", qsTr("Sol AirPod"), 1], ["right", qsTr("Sağ AirPod"), 2], ["case", qsTr("Kutu"), 3]]
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
                            text: cell.now !== null && Store.charging(cell.modelData[0]) ? qsTr("Şarj oluyor")
                                : cell.last ? qsTr("Son bilinen, %1").arg(Store.ago(cell.last.at))
                                : cell.lvl === null ? (cell.modelData[0] === "case" ? qsTr("Kutuyu aç") : qsTr("Bilinmiyor"))
                                : cell.ear === "ear" ? qsTr("Kulakta") : cell.ear === "case" ? qsTr("Kutuda") : cell.ear === "out" ? qsTr("Dışarıda") : ""
                            font: Theme.footnote
                            color: Theme.text2
                        }
                    }
                }
            }
        }
    }

    Section {
        title: qsTr("Kulaklık")
        Setting {
            title: qsTr("Ad")
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
            title: qsTr("Otomatik Bağlan")
            subtitle: qsTr("Kulaklık yakındaki aygıtlar arasında kendiliğinden bu bilgisayara geçebilir.")
            enabled: Store.ready
            Switch {
                checked: Store.setting("autoConnect", true)
                onToggled: v => Backend.setSetting("autoConnect", v)
            }
        }
        Setting {
            title: qsTr("Bağlantı")
            subtitle: Store.live ? qsTr("Bu bilgisayara bağlı") : qsTr("Bağlı değil")
            enabled: Backend.daemon
            Button {
                text: Store.live ? qsTr("Bağlantıyı Kes") : qsTr("Bağlan")
                onClicked: Store.live ? Backend.disconnectDevice() : Backend.connectDevice()
            }
        }
    }

    Section {
        title: qsTr("Pil Geçmişi")
        Block {
            BatteryChart { width: parent.width }
        }
    }

    Section {
        title: qsTr("Eşli Kulaklıklar")
        footer: Store.s.discovering ? qsTr("Kutunun kapağını aç ve arkasındaki düğmeyi ışık beyaz yanıp sönene kadar basılı tut.") : ""
        Repeater {
            model: Store.devices
            Setting {
                id: dev
                required property var modelData
                readonly property bool current: modelData.address === Store.s.address
                title: modelData.name + (current ? "  ·  " + qsTr("seçili") : "")
                subtitle: (modelData.modelName || "") + (modelData.connected ? "  ·  " + qsTr("bağlı") : "")
                onMenu: devMenu.popup()
                Button {
                    visible: !dev.current || !dev.modelData.connected
                    text: dev.current ? qsTr("Bağlan") : qsTr("Bu Kulaklığa Geç")
                    onClicked: Backend.select(dev.modelData.address)
                }
                Button {
                    text: qsTr("Unut")
                    destructive: true
                    onClicked: page.confirm.ask(qsTr("%1 unutulsun mu?").arg(dev.modelData.name),
                        qsTr("Eşleşme bu bilgisayardan silinir. Yeniden kullanmak için kulaklığı tekrar eşleştirmen gerekir."),
                        "", qsTr("Unut"), () => Backend.forget(dev.modelData.address))
                }
                Menu {
                    id: devMenu
                    MenuItemLike { text: qsTr("Adresi Kopyala"); onTriggered: Backend.copy(dev.modelData.address) }
                    MenuItemLike { text: qsTr("Unut…"); onTriggered: Backend.forget(dev.modelData.address) }
                }
            }
        }
        Repeater {
            model: Store.s.nearby || []
            Setting {
                required property var modelData
                title: modelData.name || modelData.address
                subtitle: qsTr("Eşleştirmeye hazır")
                Button { primary: true; text: qsTr("Eşleştir"); onClicked: Backend.pair(parent.parent.modelData.address) }
            }
        }
        Setting {
            title: Store.s.discovering ? qsTr("Aranıyor…") : qsTr("Yeni kulaklık eşleştir")
            enabled: Backend.daemon
            Spinner { visible: !!Store.s.discovering; size: 14 }
            Button {
                text: Store.s.discovering ? qsTr("Durdur") : qsTr("Ara")
                onClicked: Backend.discover(!Store.s.discovering)
            }
        }
    }
}
