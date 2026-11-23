import QtQuick
import Pinna
import QtQuick.Shapes

SettingRow {
    id: root
    property bool checked
    property bool locked: false
    signal toggled(bool value)
    clickable: !locked || !checked
    onClicked: toggled(!checked)

    Shape {
        width: 18
        height: 18
        opacity: root.checked ? 1 : 0
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity { NumberAnimation { duration: 90 } }
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 2; startY: 9.5
            PathLine { x: 7; y: 14.5 }
            PathLine { x: 16; y: 4 }
        }
    }
}
