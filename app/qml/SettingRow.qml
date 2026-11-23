import QtQuick
import QtQuick.Shapes
import Pinna

// Grup içindeki tek satır. Sağdaki kontrol `trailing` ile, alttaki ek içerik `below` ile gelir.
Item {
    id: root
    property string title
    property string subtitle
    property string value
    property bool chevron: false
    property bool clickable: chevron
    property bool centered: false
    property real leftInset: Theme.pad
    property color titleColor: Theme.text
    readonly property bool pressed: mouse.pressed
    default property alias trailing: trail.data
    property alias below: extra.data
    signal clicked()

    readonly property real headHeight: Math.max(Theme.rowHeight, head.implicitHeight + 22)
    width: parent ? parent.width : 0
    height: headHeight + (extra.children.length ? extra.childrenRect.height + 14 : 0)
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: clickable
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    // görünen son kardeşte ayırıcı çizgi yok
    readonly property bool isLast: {
        const c = parent ? parent.children : []
        let last = null
        for (let i = 0; i < c.length; i++)
            if (c[i].visible && c[i].height > 0) last = c[i]
        return last === root
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.groupHover
        visible: root.clickable && mouse.containsMouse && !mouse.pressed
    }
    // iOS'taki gibi basınca hemen koyulaşır, bırakınca yavaşça söner
    Rectangle {
        anchors.fill: parent
        color: Theme.groupPress
        opacity: root.clickable && mouse.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: mouse.pressed ? 0 : 250; easing.type: Easing.OutQuad } }
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
        radius: Theme.radius
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable && root.enabled
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Column {
        id: head
        anchors.left: parent.left
        anchors.leftMargin: root.leftInset
        anchors.right: root.centered ? parent.right : side.left
        anchors.rightMargin: root.centered ? Theme.pad : 10
        y: (root.headHeight - implicitHeight) / 2
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            font: Theme.body
            color: root.titleColor
            elide: Text.ElideRight
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
        }
        Text {
            width: parent.width
            visible: root.subtitle.length > 0
            text: root.subtitle
            font: Theme.footnote
            color: Theme.text2
            wrapMode: Text.WordWrap
            lineHeight: 1.1
        }
    }

    Row {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        y: (root.headHeight - height) / 2
        spacing: 8

        Text {
            visible: root.value.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            font: Theme.body
            color: Theme.text2
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width * 0.55)
        }
        Item {
            id: trail
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
            visible: children.length > 0
        }
        Shape {
            visible: root.chevron
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 14
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.text3
                strokeWidth: 2.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 1.5; startY: 1.5
                PathLine { x: 6.5; y: 7 }
                PathLine { x: 1.5; y: 12.5 }
            }
        }
    }

    Item {
        id: extra
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        y: root.headHeight - 6
        height: childrenRect.height
    }

    Rectangle {
        visible: !root.isLast
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: root.leftInset
        anchors.right: parent.right
        height: 1
        color: Theme.separator
    }
}
