import QtQuick
import Pinna

SettingRow {
    id: root
    property var options: []
    property int current: 0
    signal picked(int index)

    below: Segmented {
        width: parent.width
        model: root.options
        currentIndex: root.current
        onActivated: i => root.picked(i)
    }
}
