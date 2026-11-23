import QtQuick
import Earshot
import QtQuick.Shapes

// Dinleme modlarının çizgi ikonları: baş silueti ve etrafındaki ses dalgaları.
Shape {
    id: root
    property string mode: "anc"
    property color color: Theme.text
    width: 26
    height: 26
    preferredRendererType: Shape.CurveRenderer

    readonly property real c: width / 2

    // ortadaki dolu nokta: dinleyen kişi
    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.color
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: 3.2; radiusY: 3.2; startAngle: 0; sweepAngle: 360 }
    }

    // gürültü engelleme: kapalı kalın halka
    ShapePath {
        strokeWidth: root.mode === "anc" ? 2.2 : 0
        strokeColor: root.mode === "anc" ? root.color : "transparent"
        fillColor: "transparent"
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: 9; radiusY: 9; startAngle: 0; sweepAngle: 360 }
    }

    // şeffaf: kesik halka, ses içeri giriyor
    ShapePath {
        strokeWidth: root.mode === "transparency" ? 2 : 0
        strokeColor: root.mode === "transparency" ? root.color : "transparent"
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [1.6, 2.2]
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: 9; radiusY: 9; startAngle: 0; sweepAngle: 360 }
    }

    // uyarlanabilir: yarısı dolu yarısı kesik
    ShapePath {
        strokeWidth: root.mode === "adaptive" ? 2.2 : 0
        strokeColor: root.mode === "adaptive" ? root.color : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: 9; radiusY: 9; startAngle: 90; sweepAngle: 180 }
    }
    ShapePath {
        strokeWidth: root.mode === "adaptive" ? 2 : 0
        strokeColor: root.mode === "adaptive" ? root.color : "transparent"
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [1.6, 2.2]
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: 9; radiusY: 9; startAngle: -90; sweepAngle: 180 }
    }

    // kapalı: ince halka ve çapraz çizgi
    ShapePath {
        strokeWidth: root.mode === "off" ? 1.6 : 0
        strokeColor: root.mode === "off" ? root.color : "transparent"
        fillColor: "transparent"
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: 9; radiusY: 9; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        strokeWidth: root.mode === "off" ? 1.8 : 0
        strokeColor: root.mode === "off" ? root.color : "transparent"
        capStyle: ShapePath.RoundCap
        startX: root.c - 7; startY: root.c + 7
        PathLine { x: root.c + 7; y: root.c - 7 }
    }
}
