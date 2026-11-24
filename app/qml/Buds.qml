import QtQuick
import Pinna

// The pair of buds. White buds need a shadow on a light background; a baked image works on every renderer.
Row {
    id: root
    property real budWidth: 22
    property real budHeight: 40
    property bool shadow: !Theme.dark
    spacing: -3
    Repeater {
        model: [false, true]
        Item {
            required property bool modelData
            width: root.budWidth
            height: root.budHeight
            Image {
                visible: root.shadow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.max(1, root.budHeight / 40)
                width: parent.width * 556 / 508
                height: parent.height * 734 / 686
                source: "../assets/bud-shadow.png"
                mirror: parent.modelData
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            Image {
                anchors.fill: parent
                source: "../assets/bud.png"
                mirror: parent.modelData
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
        }
    }
}
