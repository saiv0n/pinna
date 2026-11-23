import QtQuick
import QtQuick.Shapes
import Pinna

// Dinleme modu ikonları: ortada dinleyen kişi, çevresinde sesin geçişini anlatan halka.
Shape {
    id: root
    property string mode: "anc"
    property color color: Theme.text
    width: 28
    height: 28
    preferredRendererType: Shape.CurveRenderer

    readonly property real c: 14
    readonly property real r: 11.5
    readonly property color none: "transparent"

    // baş ve omuzlar
    ShapePath {
        strokeColor: root.none
        fillColor: root.color
        PathAngleArc { centerX: root.c; centerY: 10.6; radiusX: 3.7; radiusY: 3.7; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        strokeColor: root.none
        fillColor: root.color
        startX: 7.4; startY: 21
        PathCubic { control1X: 7.4; control1Y: 16.6; control2X: 10.4; control2Y: 15.4; x: 14; y: 15.4 }
        PathCubic { control1X: 17.6; control1Y: 15.4; control2X: 20.6; control2Y: 16.6; x: 20.6; y: 21 }
        PathQuad { controlX: 20.6; controlY: 21.8; x: 19.6; y: 21.8 }
        PathLine { x: 8.4; y: 21.8 }
        PathQuad { controlX: 7.4; controlY: 21.8; x: 7.4; y: 21 }
    }

    // gürültü engelleme: kapalı, kalın halka
    ShapePath {
        strokeColor: root.mode === "anc" ? root.color : root.none
        strokeWidth: 2.4
        fillColor: root.none
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.r; radiusY: root.r; startAngle: 0; sweepAngle: 360 }
    }

    // şeffaflık: noktalı halka, ses içeri giriyor
    ShapePath {
        strokeColor: root.mode === "transparency" ? root.color : root.none
        strokeWidth: 2.1
        fillColor: root.none
        capStyle: ShapePath.RoundCap
        strokeStyle: ShapePath.DashLine
        dashPattern: [0.01, 2.05]
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.r; radiusY: root.r; startAngle: 0; sweepAngle: 360 }
    }

    // uyarlanabilir: yarısı kapalı, yarısı noktalı, köşede parıltı
    ShapePath {
        strokeColor: root.mode === "adaptive" ? root.color : root.none
        strokeWidth: 2.4
        fillColor: root.none
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.r; radiusY: root.r; startAngle: 90; sweepAngle: 175 }
    }
    ShapePath {
        strokeColor: root.mode === "adaptive" ? root.color : root.none
        strokeWidth: 2.1
        fillColor: root.none
        capStyle: ShapePath.RoundCap
        strokeStyle: ShapePath.DashLine
        dashPattern: [0.01, 2.05]
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.r; radiusY: root.r; startAngle: -18; sweepAngle: 100 }
    }
    readonly property real x0: 21.6
    readonly property real y0: 5.2
    readonly property real k: 4.6
    ShapePath {
        strokeColor: root.none
        fillColor: root.mode === "adaptive" ? root.color : root.none
        startX: root.x0; startY: root.y0 - root.k
        PathQuad { controlX: root.x0 + 0.8; controlY: root.y0 - 0.8; x: root.x0 + root.k; y: root.y0 }
        PathQuad { controlX: root.x0 + 0.8; controlY: root.y0 + 0.8; x: root.x0; y: root.y0 + root.k }
        PathQuad { controlX: root.x0 - 0.8; controlY: root.y0 + 0.8; x: root.x0 - root.k; y: root.y0 }
        PathQuad { controlX: root.x0 - 0.8; controlY: root.y0 - 0.8; x: root.x0; y: root.y0 - root.k }
    }
}
