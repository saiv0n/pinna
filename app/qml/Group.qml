import QtQuick
import Pinna

// Başlığı ve açıklaması olan, köşeleri yuvarlak satır grubu.
Column {
    id: root
    property string title
    property string footer
    default property alias rows: list.data
    width: parent ? parent.width : 0
    spacing: 7

    Text {
        visible: root.title.length > 0
        text: root.title
        font: Theme.section
        color: Theme.header
        leftPadding: Theme.pad
    }

    Rectangle {
        width: parent.width
        height: list.height
        radius: Theme.radius
        color: Theme.group
        clip: true
        // satır açılıp kapanınca grup sıçramasın, yumuşakça uzasın
        Behavior on height { enabled: !Theme.reduce && root.visible; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Column {
            id: list
            width: parent.width
        }
    }

    Text {
        visible: root.footer.length > 0
        text: root.footer
        font: Theme.footnote
        color: Theme.text2
        width: parent.width
        wrapMode: Text.WordWrap
        leftPadding: Theme.pad
        rightPadding: Theme.pad
        lineHeight: 1.15
    }
}
