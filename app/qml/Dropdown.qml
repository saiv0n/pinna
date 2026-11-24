import QtQuick
import QtQuick.Shapes
import QtQuick.Controls.Basic as C
import Pinna

C.ComboBox {
    id: root
    signal picked(int index)
    onActivated: i => picked(i)
    property string label
    Accessible.name: label
    Accessible.description: displayText

    implicitWidth: Math.max(120, textWidth + 44)
    readonly property real textWidth: {
        let w = 0
        for (let i = 0; i < count; i++)
            w = Math.max(w, metrics.advanceWidth(textAt(i)))
        return Math.ceil(w)
    }
    FontMetrics { id: metrics; font: Theme.body }
    implicitHeight: 28
    font: Theme.body
    leftPadding: 10
    rightPadding: 26
    opacity: enabled ? 1 : 0.45

    background: Rectangle {
        radius: Theme.small
        color: root.pressed ? Theme.press : root.hovered ? Theme.controlHover : Theme.control
        FocusRing { target: root }
    }
    contentItem: Text {
        text: root.displayText
        font: root.font
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Shape {
        x: root.width - 18
        y: (root.height - height) / 2
        width: 8
        height: 10
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.text2
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            startX: 1; startY: 3.5
            PathLine { x: 4; y: 0.8 }
            PathLine { x: 7; y: 3.5 }
            PathMove { x: 1; y: 6.5 }
            PathLine { x: 4; y: 9.2 }
            PathLine { x: 7; y: 6.5 }
        }
    }
    delegate: C.ItemDelegate {
        id: item
        required property int index
        required property var modelData
        width: root.popup.width - 8
        x: 4
        height: 28
        hoverEnabled: true
        contentItem: Text {
            text: root.textAt(item.index)
            font: Theme.body
            color: item.highlighted ? Theme.accentText : Theme.text
            verticalAlignment: Text.AlignVCenter
            leftPadding: 4
        }
        highlighted: root.highlightedIndex === index
        background: Rectangle {
            radius: 4
            color: item.highlighted ? Theme.accent : "transparent"
        }
    }
    popup: C.Popup {
        y: root.height + 4
        width: Math.max(root.width, root.textWidth + 40)
        implicitHeight: list.contentHeight + 8
        padding: 4
        contentItem: ListView {
            id: list
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
        background: Rectangle {
            radius: 8
            color: Theme.card
            border.width: 1
            border.color: Theme.border
        }
    }
}
