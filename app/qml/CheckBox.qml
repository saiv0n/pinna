import QtQuick
import QtQuick.Shapes
import Pinna

Item {
    id: root
    property bool checked
    property bool locked: false
    signal toggled(bool value)
    function flip() { if (enabled && !(locked && checked)) toggled(!checked) }

    implicitWidth: 16
    implicitHeight: 16
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onSpacePressed: flip()
    property string label
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.checked ? (root.locked ? Theme.text3 : Theme.accent) : Theme.card
        border.width: root.checked ? 0 : 1
        border.color: Theme.text3
    }
    FocusRing { r: 4 }
    Shape {
        anchors.fill: parent
        visible: root.checked
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#ffffff"
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            startX: 4; startY: 8.5
            PathLine { x: 7; y: 11.5 }
            PathLine { x: 12; y: 5 }
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        onClicked: root.flip()
    }
}
