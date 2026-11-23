import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

C.Slider {
    id: root
    property real target
    // sürüklerken değil bırakınca gönderilsin diye
    signal committed(real value)
    onPressedChanged: if (!pressed) committed(value)
    Binding on value { when: !root.pressed; value: root.target }

    implicitHeight: 30
    padding: 0
    stepSize: 1

    background: Item {
        x: root.leftPadding
        width: root.availableWidth
        height: root.height
        Rectangle {
            y: (parent.height - height) / 2
            width: parent.width
            height: 4
            radius: 2
            color: Theme.sliderTrack
            Rectangle {
                width: 14 + root.visualPosition * (parent.width - 28)
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: 28
        height: 28
        radius: 14
        color: "#ffffff"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
        scale: root.pressed ? 1.08 : 1
        Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.005 } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -0.5
            anchors.bottomMargin: -2
            z: -1
            radius: width / 2
            color: Theme.dark ? "#60000000" : "#26000000"
        }
    }
}
