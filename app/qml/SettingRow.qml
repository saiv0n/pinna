import QtQuick
import Earshot

// Grup içindeki tek satır. Sağ taraftaki kontrol `trailing` ile, alttaki ek içerik `below` ile gelir.
Item {
    id: root
    property string title
    property string subtitle
    property bool clickable: false
    property color titleColor: Theme.text
    default property alias trailing: trail.data
    property alias below: extra.data
    signal clicked()

    width: parent ? parent.width : 0
    height: Math.max(Theme.rowHeight, head.implicitHeight + 24) + (extra.children.length ? extra.childrenRect.height + 12 : 0)

    // görünen son kardeşte ayırıcı çizgi yok
    readonly property bool isLast: {
        const c = parent ? parent.children : []
        let last = null
        for (let i = 0; i < c.length; i++)
            if (c[i].visible) last = c[i]
        return last === root
    }

    Rectangle {
        anchors.fill: parent
        color: mouse.pressed ? Theme.groupPress : Theme.groupHover
        opacity: root.clickable && (mouse.containsMouse || mouse.pressed) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Column {
        id: head
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad
        anchors.right: trail.left
        anchors.rightMargin: 12
        y: (Math.max(Theme.rowHeight, implicitHeight + 24) - implicitHeight) / 2
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            font: Theme.body
            color: root.titleColor
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: root.subtitle.length > 0
            text: root.subtitle
            font: Theme.caption
            color: Theme.text2
            wrapMode: Text.WordWrap
            lineHeight: 1.1
        }
    }

    Item {
        id: trail
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        y: (Math.max(Theme.rowHeight, head.implicitHeight + 24) - height) / 2
        width: childrenRect.width
        height: childrenRect.height
    }

    Item {
        id: extra
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        y: Math.max(Theme.rowHeight, head.implicitHeight + 24) - 4
        height: childrenRect.height
    }

    Rectangle {
        visible: !root.isLast
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad
        anchors.right: parent.right
        height: 1
        color: Theme.separator
    }
}
