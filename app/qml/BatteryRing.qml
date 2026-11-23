import QtQuick
import QtQuick.Shapes
import Pinna

// Bağlantı kartındaki pil halkası. Ortasında aygıtın küçük resmi, altında yüzde.
Item {
    id: root
    property var level: null
    property bool charging: false
    property real size: 58
    property int delay: 0
    default property alias icon: center.data

    width: size
    height: size + 24

    readonly property bool known: level !== null && level !== undefined
    readonly property real target: known ? level / 100 : 0
    readonly property color tone: !known ? "transparent"
        : charging ? Theme.green
        : level <= 20 ? Theme.red
        : Theme.green

    // ilk görünüşte sırayla, boştan dolarak gelir
    property real shown: 0
    property bool started: Theme.reduce
    Timer { interval: root.delay + 180; running: true; onTriggered: root.started = true }
    Binding on shown { when: root.started; value: root.target }
    Behavior on shown { enabled: !Theme.reduce; NumberAnimation { duration: 900; easing.type: Easing.OutQuart } }

    Shape {
        id: ring
        width: root.size
        height: root.size
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.dark ? "#3a3a3c" : "#e5e5ea"
            strokeWidth: 4.5
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - 3; radiusY: ring.height / 2 - 3
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.tone
            strokeWidth: 4.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - 3; radiusY: ring.height / 2 - 3
                startAngle: -90; sweepAngle: 360 * root.shown
            }
        }

        Item {
            id: center
            anchors.fill: parent
            opacity: root.known ? 1 : 0.4
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 3
        Shape {
            visible: root.charging
            width: 7
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.green
                strokeColor: "transparent"
                startX: 4.5; startY: 0
                PathLine { x: 0.3; y: 6.4 }
                PathLine { x: 3.2; y: 6.4 }
                PathLine { x: 2.4; y: 11 }
                PathLine { x: 6.7; y: 4.6 }
                PathLine { x: 3.9; y: 4.6 }
                PathLine { x: 4.5; y: 0 }
            }
        }
        Text {
            text: root.known ? root.level + "%" : "—"
            font.pixelSize: 13
            font.weight: 600
            font.features: { "tnum": 1 }
            color: root.known && root.level <= 20 && !root.charging ? Theme.red : Theme.text
        }
    }
}
