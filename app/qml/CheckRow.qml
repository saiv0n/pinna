import QtQuick
import QtQuick.Shapes
import Pinna

// Listeden seçim satırı; seçiliyse sağda mavi tik.
SettingRow {
    id: root
    property bool checked
    property bool locked: false
    signal toggled(bool value)
    clickable: !(locked && checked)
    onClicked: if (!(locked && checked)) toggled(!checked)

    Shape {
        width: 16
        height: 14
        opacity: root.checked ? 1 : 0
        scale: root.checked ? 1 : 0.6
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.01 } }
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: 2.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 1.5; startY: 7.5
            PathLine { x: 6; y: 12 }
            PathLine { x: 14.5; y: 1.8 }
        }
    }
}
