import QtQuick
import Pinna

// An eight spoke activity indicator.
Item {
    id: root
    property real size: 20
    property color color: Theme.text2
    width: size
    height: size

    property int step: 0
    Timer {
        interval: 90
        repeat: true
        running: root.visible
        onTriggered: root.step = (root.step + 1) % 8
    }

    Repeater {
        model: 8
        Rectangle {
            required property int index
            x: (root.size - width) / 2
            y: 0
            width: Math.max(1.6, root.size * 0.1)
            height: root.size * 0.3
            radius: width / 2
            color: root.color
            opacity: 0.18 + 0.82 * (((index - root.step + 8) % 8) / 7)
            transform: Rotation { origin.x: width / 2; origin.y: root.size / 2; angle: index * 45 }
        }
    }
}
