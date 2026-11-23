import QtQuick
import Earshot
import QtQuick.Controls.Basic as C

C.Slider {
    id: root
    implicitHeight: 28
    padding: 0
    // sürüklerken değil bırakınca gönderilsin diye
    signal committed(real value)
    onPressedChanged: if (!pressed) committed(value)

    background: Item {
        x: root.leftPadding
        width: root.availableWidth
        height: root.height
        Rectangle {
            y: (parent.height - height) / 2
            width: parent.width
            height: 4
            radius: 2
            color: Theme.track
            Rectangle {
                width: root.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: 24
        height: 24
        radius: 12
        color: "#ffffff"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
        scale: root.pressed ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -0.5
            z: -1
            radius: width / 2
            color: "#30000000"
        }
    }
}
