import QtQuick
import QtQuick.Shapes
import Pinna

// Listening mode glyphs: a filled bust and a mark around it. Even stroke widths.
Shape {
    id: root
    property string mode: "anc"
    property color color: Theme.text
    width: 28
    height: 28
    preferredRendererType: Shape.CurveRenderer

    readonly property color none: "transparent"
    readonly property real line: 1.7
    // in adaptive the bust shifts left to make room for the sparkles
    readonly property real bx: mode === "adaptive" ? 11.5 : 14
    readonly property real by: mode === "anc" ? 1 : 2

    // head
    ShapePath {
        strokeColor: root.mode === "off" ? root.color : root.none
        strokeWidth: root.line
        fillColor: root.mode === "off" ? root.none : root.color
        PathAngleArc { centerX: root.bx; centerY: 9.6 + root.by; radiusX: 3.6; radiusY: 3.6; startAngle: 0; sweepAngle: 360 }
    }
    // shoulders
    ShapePath {
        strokeColor: root.mode === "off" ? root.color : root.none
        strokeWidth: root.line
        joinStyle: ShapePath.RoundJoin
        fillColor: root.mode === "off" ? root.none : root.color
        startX: root.bx - 6.4; startY: 20.4 + root.by
        PathCubic { control1X: root.bx - 6.4; control1Y: 16.2 + root.by; control2X: root.bx - 3.4; control2Y: 14.6 + root.by; x: root.bx; y: 14.6 + root.by }
        PathCubic { control1X: root.bx + 3.4; control1Y: 14.6 + root.by; control2X: root.bx + 6.4; control2Y: 16.2 + root.by; x: root.bx + 6.4; y: 20.4 + root.by }
        PathQuad { controlX: root.bx + 6.4; controlY: 21.4 + root.by; x: root.bx + 5.4; y: 21.4 + root.by }
        PathLine { x: root.bx - 5.4; y: 21.4 + root.by }
        PathQuad { controlX: root.bx - 6.4; controlY: 21.4 + root.by; x: root.bx - 6.4; y: 20.4 + root.by }
    }

    // noise cancellation: a closed ring around the bust
    ShapePath {
        strokeColor: root.mode === "anc" ? root.color : root.none
        strokeWidth: root.line
        fillColor: root.none
        PathAngleArc { centerX: 14; centerY: 14; radiusX: 12.2; radiusY: 12.2; startAngle: 0; sweepAngle: 360 }
    }

    // transparency: sound rays reaching the head from outside
    ShapePath {
        strokeColor: root.mode === "transparency" ? root.color : root.none
        strokeWidth: root.line
        capStyle: ShapePath.RoundCap
        fillColor: root.none
        startX: 0; startY: 0
        PathMove { x: 7.40; y: 11.80 }
        PathLine { x: 4.80; y: 11.80 }
        PathMove { x: 8.28; y: 8.50 }
        PathLine { x: 6.03; y: 7.20 }
        PathMove { x: 10.70; y: 6.08 }
        PathLine { x: 9.40; y: 3.83 }
        PathMove { x: 14.00; y: 5.20 }
        PathLine { x: 14.00; y: 2.60 }
        PathMove { x: 17.30; y: 6.08 }
        PathLine { x: 18.60; y: 3.83 }
        PathMove { x: 19.72; y: 8.50 }
        PathLine { x: 21.97; y: 7.20 }
        PathMove { x: 20.60; y: 11.80 }
        PathLine { x: 23.20; y: 11.80 }
    }

    // adaptive: one big and one small sparkle
    ShapePath {
        strokeColor: root.none
        fillColor: root.mode === "adaptive" ? root.color : root.none
        startX: 21.6; startY: 1.60
        PathQuad { controlX: 22.52; controlY: 5.28; x: 26.20; y: 6.2 }
        PathQuad { controlX: 22.52; controlY: 7.12; x: 21.6; y: 10.80 }
        PathQuad { controlX: 20.68; controlY: 7.12; x: 17.00; y: 6.2 }
        PathQuad { controlX: 20.68; controlY: 5.28; x: 21.6; y: 1.60 }
    }
    ShapePath {
        strokeColor: root.none
        fillColor: root.mode === "adaptive" ? root.color : root.none
        startX: 24.8; startY: 11.00
        PathQuad { controlX: 25.28; controlY: 12.92; x: 27.20; y: 13.4 }
        PathQuad { controlX: 25.28; controlY: 13.88; x: 24.8; y: 15.80 }
        PathQuad { controlX: 24.32; controlY: 13.88; x: 22.40; y: 13.4 }
        PathQuad { controlX: 24.32; controlY: 12.92; x: 24.8; y: 11.00 }
    }
}
