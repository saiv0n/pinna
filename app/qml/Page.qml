import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

// The scrollable page on the right. Content stays centered in wide windows.
Flickable {
    id: root
    property string title
    property string subtitle
    default property alias content: col.data
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 56
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 4000
    maximumFlickVelocity: 5000
    pixelAligned: true
    Keys.onPressed: e => {
        const step = e.key === Qt.Key_PageDown ? height * 0.9 : e.key === Qt.Key_PageUp ? -height * 0.9
                   : e.key === Qt.Key_End ? contentHeight : e.key === Qt.Key_Home ? -contentHeight : 0
        if (step) { contentY = Math.max(0, Math.min(contentHeight - height, contentY + step)); e.accepted = true }
    }
    C.ScrollBar.vertical: C.ScrollBar {
        width: 8
        contentItem: Rectangle { radius: 3; color: Theme.text3; opacity: 0.6 }
    }

    Column {
        id: col
        x: Math.max(28, (root.width - width) / 2)
        y: 28
        width: Math.min(root.width - 56, 640)
        spacing: 22
        Column {
            width: parent.width
            spacing: 3
            Text { text: root.title; font: Theme.title; color: Theme.text }
            Text {
                visible: !!root.subtitle
                width: parent.width
                text: root.subtitle
                font: Theme.body
                color: Theme.text2
                wrapMode: Text.Wrap
            }
        }
    }
}
