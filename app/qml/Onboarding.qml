import QtQuick
import Pinna

// Bu bilgisayarla eşli hiç AirPods yokken: adım adım eşleştirme.
StatusView {
    id: root
    readonly property bool searching: !!Store.s.discovering
    readonly property var nearby: Store.s.nearby || []
    property string pairing: ""
    title: qsTr("AirPods'unu bağla")
    text: searching
        ? qsTr("AirPods kutudayken kapağı aç ve kutunun arkasındaki düğmeyi ışık beyaz yanıp sönene kadar basılı tut.")
        : qsTr("Pinna, bu bilgisayarla eşleşmiş AirPods ya da Beats kulaklıkları yönetir. Başlamak için kulaklığını eşleştir.")
    action: searching ? "" : qsTr("Eşleştirmeye Başla")
    onTriggered: Backend.discover(true)
    Connections {
        target: Backend
        function onError() { root.pairing = "" }
    }

    Section {
        visible: root.searching
        Setting {
            visible: root.nearby.length === 0
            title: qsTr("Aranıyor…")
            Spinner { size: 14 }
            Button { text: qsTr("Durdur"); onClicked: Backend.discover(false) }
        }
        Repeater {
            model: root.nearby
            Setting {
                id: found
                required property var modelData
                title: modelData.name || modelData.address
                subtitle: qsTr("Eşleştirmeye hazır")
                Button {
                    primary: true
                    busy: root.pairing === found.modelData.address
                    text: busy ? qsTr("Eşleştiriliyor…") : qsTr("Eşleştir")
                    onClicked: { root.pairing = found.modelData.address; Backend.pair(found.modelData.address) }
                }
            }
        }
    }
}
