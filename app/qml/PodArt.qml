import QtQuick
import Pinna

// İki kulaklık yan yana; kulakta olmayan hafifçe solar.
Item {
    id: root
    property bool leftActive: true
    property bool rightActive: true
    property real scaleFactor: 1
    implicitWidth: 260 * scaleFactor
    implicitHeight: 180 * scaleFactor

    Image {
        source: "../assets/bud.png"
        width: 124 * root.scaleFactor
        height: 168 * root.scaleFactor
        fillMode: Image.PreserveAspectFit
        x: root.width / 2 - width - 2 * root.scaleFactor
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.leftActive ? 1 : 0.45
        smooth: true
        mipmap: true
        Behavior on opacity { NumberAnimation { duration: Theme.medium } }
    }

    Image {
        source: "../assets/bud.png"
        mirror: true
        width: 124 * root.scaleFactor
        height: 168 * root.scaleFactor
        fillMode: Image.PreserveAspectFit
        x: root.width / 2 + 2 * root.scaleFactor
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.rightActive ? 1 : 0.45
        smooth: true
        mipmap: true
        Behavior on opacity { NumberAnimation { duration: Theme.medium } }
    }
}
