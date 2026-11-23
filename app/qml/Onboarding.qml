import QtQuick
import Pinna

// When no AirPods are paired yet: step by step pairing.
StatusView {
    id: root
    readonly property bool searching: !!Store.s.discovering
    readonly property var nearby: Store.s.nearby || []
    property string pairing: ""
    title: qsTr("Connect your AirPods")
    text: searching
        ? qsTr("With your AirPods in the case, open the lid and hold the button on the back until the light flashes white.")
        : qsTr("Pinna manages AirPods and Beats headphones paired with this computer. Pair your headphones to get started.")
    action: searching ? "" : qsTr("Start Pairing")
    onTriggered: Backend.discover(true)
    Connections {
        target: Backend
        function onError() { root.pairing = "" }
    }

    Section {
        visible: root.searching
        Setting {
            visible: root.nearby.length === 0
            title: qsTr("Searching…")
            Spinner { size: 14 }
            Button { text: qsTr("Stop"); onClicked: Backend.discover(false) }
        }
        Repeater {
            model: root.nearby
            Setting {
                id: found
                required property var modelData
                title: modelData.name || modelData.address
                subtitle: qsTr("Ready to pair")
                Button {
                    primary: true
                    busy: root.pairing === found.modelData.address
                    text: busy ? qsTr("Pairing…") : qsTr("Pair")
                    onClicked: { root.pairing = found.modelData.address; Backend.pair(found.modelData.address) }
                }
            }
        }
    }
}
