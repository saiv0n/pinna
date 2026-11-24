import QtQuick
import Pinna

// A status screen over the content area: what happened, what to do, and one button.
Item {
    id: root
    property string title
    property string text
    property string action
    property bool busy: false
    default property alias extra: more.data
    signal triggered()

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 420)
        spacing: 10
        Buds {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -4
            opacity: Theme.dark ? 0.85 : 0.75
            budWidth: 44
            budHeight: 76
        }
        Item { width: 1; height: 6 }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            font: Theme.title
            color: Theme.text
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            font: Theme.body
            color: Theme.text2
            wrapMode: Text.Wrap
            lineHeight: 1.15
        }
        Item { width: 1; height: 6 }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!root.action
            primary: true
            busy: root.busy
            text: root.action
            onClicked: root.triggered()
        }
        Column {
            id: more
            width: parent.width
            spacing: 8
        }
    }
}
