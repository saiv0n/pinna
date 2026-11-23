import QtQuick
import Earshot

// Başlığı ve açıklaması olan, köşeleri yuvarlak satır grubu.
Column {
    id: root
    property string title
    property string footer
    default property alias rows: list.data
    width: parent ? parent.width : 0
    spacing: 6

    Text {
        visible: root.title.length > 0
        text: root.title
        font: Theme.section
        color: Theme.text2
        leftPadding: Theme.pad
    }

    Rectangle {
        width: parent.width
        height: list.height
        radius: Theme.radius
        color: Theme.group
        clip: true

        Column {
            id: list
            width: parent.width
        }
    }

    Text {
        visible: root.footer.length > 0
        text: root.footer
        font: Theme.caption
        color: Theme.text3
        width: parent.width
        wrapMode: Text.WordWrap
        leftPadding: Theme.pad
        rightPadding: Theme.pad
        lineHeight: 1.15
    }
}
