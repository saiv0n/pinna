import QtQuick
import QtQuick.Shapes
import Pinna

// Battery ring. The caller adds the label; a bolt shows while charging.
Item {
    id: root
    property var level: null
    property bool charging: false
    property real size: 34
    property real stroke: 3
    width: size
    height: size

    readonly property bool known: level !== null && level !== undefined
    readonly property color tone: !known ? "transparent" : charging ? Theme.green
        : level <= 10 ? Theme.red : level <= Store.pref("lowBattery", 20) ? Theme.orange : Theme.green
    property real shown: known ? level / 100 : 0
    Behavior on shown { enabled: !Theme.reduce; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.control
            strokeWidth: root.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.size / 2 - root.stroke / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.tone
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.size / 2 - root.stroke / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 360 * root.shown
            }
        }
        ShapePath {
            fillColor: root.charging ? Theme.green : "transparent"
            strokeColor: "transparent"
            scale: Qt.size(root.size / 34, root.size / 34)
            startX: 18.5; startY: 9
            PathLine { x: 12; y: 18.5 }
            PathLine { x: 16.5; y: 18.5 }
            PathLine { x: 15.5; y: 25 }
            PathLine { x: 22; y: 15.5 }
            PathLine { x: 17.5; y: 15.5 }
            PathLine { x: 18.5; y: 9 }
        }
    }
}
