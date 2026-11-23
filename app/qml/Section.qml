import QtQuick
import Pinna

// Başlıklı ayar grubu: ince kenarlı kart, içinde satırlar.
Column {
    id: root
    property string title
    property string footer
    default property alias rows: box.data
    width: parent ? parent.width : 0
    spacing: 6

    Text {
        visible: !!root.title
        text: root.title
        font: Theme.heading
        color: Theme.text2
        leftPadding: 2
    }
    Rectangle {
        width: parent.width
        height: box.height
        radius: Theme.radius
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Column { id: box; width: parent.width }
    }
    Text {
        visible: !!root.footer
        text: root.footer
        width: parent.width
        wrapMode: Text.Wrap
        font: Theme.footnote
        color: Theme.text2
        leftPadding: 2
        rightPadding: 2
    }
}
