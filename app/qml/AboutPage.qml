import QtQuick
import Pinna

Page {
    id: page
    title: qsTr("About")

    Section {
        title: Store.name
        Repeater {
            model: [
                [qsTr("Model"), Store.s.modelName || "AirPods"],
                [qsTr("Model number"), Store.s.model || ""],
                [qsTr("Serial number"), Store.s.serial || ""],
                [qsTr("Left AirPod"), Store.s.serialLeft || ""],
                [qsTr("Right AirPod"), Store.s.serialRight || ""],
                [qsTr("Firmware"), Store.s.firmware || ""],
                [qsTr("Bluetooth address"), Store.s.address || ""]
            ]
            Setting {
                id: info
                required property var modelData
                visible: !!modelData[1]
                title: modelData[0]
                onMenu: copyMenu.popup()
                Text {
                    text: info.modelData[1]
                    font: Theme.body
                    color: Theme.text2
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: copyMenu.popup() }
                }
                Menu {
                    id: copyMenu
                    MenuItemLike { text: qsTr("Copy"); onTriggered: Backend.copy(info.modelData[1]) }
                }
            }
        }
    }

    Section {
        title: "Pinna"
        footer: qsTr("Headphone renders from Jed Falcone's AirPods Pro model (CC BY 4.0). Pinna is not affiliated with Apple.")
        Setting { title: qsTr("Version"); Text { text: Backend.version; font: Theme.body; color: Theme.text2 } }
        Setting { title: qsTr("License"); Text { text: "GPL-3.0"; font: Theme.body; color: Theme.text2 } }
    }
}
