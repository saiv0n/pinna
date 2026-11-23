import QtQuick
import Pinna
import QtQuick.Shapes

// Pil halkası. İlk görünüşte sıfırdan dolarak gelir (uygulamanın imza hareketi).
Item {
    id: root
    property var level: null
    property bool charging: false
    property string label
    property real size: 64

    width: size + 16
    height: size + 26

    readonly property bool known: level !== null && level !== undefined
    readonly property real target: known ? level / 100 : 0
    readonly property color tone: !known ? Theme.track
        : charging ? Theme.green
        : level <= 20 ? Theme.red
        : Theme.text

    property real shown: 0
    Component.onCompleted: shown = target
    onTargetChanged: shown = target
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutQuart } }

    Shape {
        id: ring
        width: root.size
        height: root.size
        anchors.horizontalCenter: parent.horizontalCenter
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.track
            strokeWidth: 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - 3; radiusY: ring.height / 2 - 3
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.tone
            strokeWidth: 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - 3; radiusY: ring.height / 2 - 3
                startAngle: -90; sweepAngle: 360 * root.shown
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.known ? root.level : "—"
                font.pixelSize: root.size * 0.3
                font.weight: 620
                font.features: { "tnum": 1 }
                color: root.known ? Theme.text : Theme.text3
            }
            Text {
                visible: root.charging
                anchors.horizontalCenter: parent.horizontalCenter
                text: "şarjda"
                font.pixelSize: 10
                font.weight: 500
                color: Theme.green
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        font: Theme.caption
        color: Theme.text2
    }
}
