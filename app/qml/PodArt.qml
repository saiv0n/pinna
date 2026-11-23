import QtQuick
import Pinna

// İki kulaklık yan yana. Açılışta ortadan yaylanarak ayrılır; kulakta olmayan geri çekilip solar.
Item {
    id: root
    property bool leftActive: true
    property bool rightActive: true
    property real scaleFactor: 1
    implicitWidth: 260 * scaleFactor
    implicitHeight: 170 * scaleFactor

    property real spread: Theme.reduce ? 1 : 0
    Component.onCompleted: spread = 1
    Behavior on spread { SpringAnimation { spring: 2.6; damping: 0.32; epsilon: 0.002 } }

    component Bud: Image {
        id: bud
        property bool active
        property int side: -1
        source: "../assets/bud.png"
        width: 116 * root.scaleFactor
        height: 157 * root.scaleFactor
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        anchors.verticalCenter: parent.verticalCenter
        x: root.width / 2 + (side < 0 ? -width - 14 : 14) * root.scaleFactor + side * (1 - root.spread) * 22 * root.scaleFactor
        rotation: side * (1 - root.spread) * -6
        opacity: (active ? 1 : 0.42) * Math.min(1, 0.3 + root.spread)
        scale: active ? 1 : 0.93
        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 3.5; damping: 0.4; epsilon: 0.002 } }
    }

    Bud { active: root.leftActive; side: -1 }
    Bud { active: root.rightActive; side: 1; mirror: true }
}
