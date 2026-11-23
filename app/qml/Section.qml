import QtQuick
import Pinna

// A titled settings group: a thin bordered card with rows.
Column {
    id: root
    property string title
    property string footer
    property bool experimental: false
    default property alias rows: box.data
    width: parent ? parent.width : 0
    spacing: 6

    Row {
        visible: !!root.title
        spacing: 6
        leftPadding: 2
        Text {
            text: root.title
            font: Theme.heading
            color: Theme.text2
        }
        Rectangle {
            visible: root.experimental
            anchors.verticalCenter: parent.verticalCenter
            width: tag.implicitWidth + 10
            height: tag.implicitHeight + 2
            radius: height / 2
            color: Qt.alpha(Theme.orange, 0.16)
            Text {
                id: tag
                anchors.centerIn: parent
                text: qsTr("Experimental")
                font.family: Theme.family
                font.pixelSize: 10
                font.weight: 600
                color: Theme.orange
            }
        }
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
