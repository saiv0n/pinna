import QtQuick
import QtQuick.Shapes
import Pinna

// Hoparlör ikonu; `waves` ile ses dalgası sayısı.
Shape {
    id: root
    property int waves: 0
    property color color: Theme.text2
    width: 20
    height: 16
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: root.color
        strokeWidth: 1
        joinStyle: ShapePath.RoundJoin
        startX: 1; startY: 5.5
        PathLine { x: 4.5; y: 5.5 }
        PathLine { x: 8.5; y: 2 }
        PathLine { x: 8.5; y: 14 }
        PathLine { x: 4.5; y: 10.5 }
        PathLine { x: 1; y: 10.5 }
        PathLine { x: 1; y: 5.5 }
    }
    ShapePath {
        strokeColor: root.waves > 0 ? root.color : "transparent"
        strokeWidth: 1.6
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 8; centerY: 8; radiusX: 4; radiusY: 4; startAngle: -45; sweepAngle: 90 }
    }
    ShapePath {
        strokeColor: root.waves > 1 ? root.color : "transparent"
        strokeWidth: 1.6
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 8; centerY: 8; radiusX: 7.5; radiusY: 7.5; startAngle: -48; sweepAngle: 96 }
    }
}
