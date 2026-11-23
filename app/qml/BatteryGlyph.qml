import QtQuick
import QtQuick.Shapes
import Pinna

// iOS durum çubuğundaki gibi yatay pil, yanında yüzde. Şarjda yeşil ve şimşekli, azsa kırmızı.
Row {
    id: root
    property var level: null
    property bool charging: false
    spacing: 5

    readonly property bool known: level !== null && level !== undefined
    readonly property color tone: charging ? Theme.green : known && level <= 20 ? Theme.red : Theme.text

    // açılışta boştan dolar
    property real shown: 0
    Component.onCompleted: shown = known ? level / 100 : 0
    onLevelChanged: shown = known ? level / 100 : 0
    Behavior on shown { enabled: !Theme.reduce; NumberAnimation { duration: 700; easing.type: Easing.OutQuart } }

    Item {
        width: 27
        height: 13
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: 24
            height: 13
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.35)
            Rectangle {
                x: 2
                y: 2
                height: parent.height - 4
                width: Math.max(root.known ? 2 : 0, (parent.width - 4) * root.shown)
                radius: 2
                color: root.tone
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        Rectangle {
            x: 25
            y: 4.5
            width: 1.6
            height: 4
            radius: 1
            color: Qt.alpha(Theme.text, 0.35)
        }
    }

    Shape {
        visible: root.charging
        width: 8
        height: 12
        anchors.verticalCenter: parent.verticalCenter
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.green
            strokeColor: "transparent"
            startX: 5; startY: 0
            PathLine { x: 0.5; y: 7 }
            PathLine { x: 3.6; y: 7 }
            PathLine { x: 2.8; y: 12 }
            PathLine { x: 7.5; y: 5 }
            PathLine { x: 4.4; y: 5 }
            PathLine { x: 5; y: 0 }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.known ? root.level + "%" : "—"
        font.pixelSize: 14
        font.weight: 500
        font.features: { "tnum": 1 }
        color: root.known && root.level <= 20 && !root.charging ? Theme.red : Theme.text
    }
}
