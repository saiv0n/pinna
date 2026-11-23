import QtQuick
import QtQuick.Shapes
import Pinna

// Küçük yuvarlak simge düğmesi: kapat ya da üç nokta.
Rectangle {
    id: root
    property string icon: "close"
    signal clicked()
    width: 24
    height: 24
    radius: 12
    color: area.pressed ? Theme.press : area.containsMouse ? Theme.hover : "transparent"
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    FocusRing { r: 12 }

    Shape {
        anchors.centerIn: parent
        width: 10
        height: 10
        visible: root.icon === "close"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.text2
            strokeWidth: 1.6
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: 1; startY: 1
            PathLine { x: 9; y: 9 }
            PathMove { x: 9; y: 1 }
            PathLine { x: 1; y: 9 }
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 3
        visible: root.icon === "more"
        Repeater {
            model: 3
            Rectangle { width: 3.5; height: 3.5; radius: 2; color: Theme.text2 }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
