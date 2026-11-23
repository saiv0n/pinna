import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

C.Slider {
    id: root
    property real target
    // sürüklerken değil bırakınca gönderilsin diye
    signal committed(real value)
    onPressedChanged: if (!pressed) committed(value)
    Keys.onReleased: e => { if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) committed(value) }
    Binding on value { when: !root.pressed; value: root.target }

    implicitWidth: 200
    implicitHeight: 20
    padding: 0
    stepSize: 1
    opacity: enabled ? 1 : 0.45

    background: Rectangle {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: root.availableWidth
        height: 4
        radius: 2
        color: Theme.control
        Rectangle {
            width: root.handle.x - root.leftPadding + root.handle.width / 2
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: 16
        height: 16
        radius: 8
        color: "#ffffff"
        border.width: 1
        border.color: Theme.dark ? "#40000000" : "#26000000"
        FocusRing { target: root; r: 8 }
    }
}
