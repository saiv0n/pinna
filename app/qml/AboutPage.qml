import QtQuick
import Pinna

Page {
    id: page
    title: qsTr("Hakkında")

    Section {
        title: Store.name
        Repeater {
            model: [
                [qsTr("Model"), Store.s.modelName || "AirPods"],
                [qsTr("Model numarası"), Store.s.model || ""],
                [qsTr("Seri numarası"), Store.s.serial || ""],
                [qsTr("Sol AirPod"), Store.s.serialLeft || ""],
                [qsTr("Sağ AirPod"), Store.s.serialRight || ""],
                [qsTr("Yazılım sürümü"), Store.s.firmware || ""],
                [qsTr("Bluetooth adresi"), Store.s.address || ""]
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
                    MenuItemLike { text: qsTr("Kopyala"); onTriggered: Backend.copy(info.modelData[1]) }
                }
            }
        }
    }

    Section {
        title: "Pinna"
        footer: qsTr("Kulaklık görseli Jed Falcone'un AirPods Pro modelinden (CC BY 4.0). Protokol notları LibrePods projesinden. Pinna'nın Apple ile bir bağı yoktur.")
        Setting { title: qsTr("Sürüm"); Text { text: Backend.version; font: Theme.body; color: Theme.text2 } }
        Setting { title: qsTr("Lisans"); Text { text: "GPL-3.0"; font: Theme.body; color: Theme.text2 } }
    }
}
