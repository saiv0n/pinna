import QtQuick
import Pinna

// Başlıklı grup içinde tek seçimli liste.
Group {
    id: root
    property var options: []
    property int current: 0
    signal picked(int index)

    Repeater {
        model: root.options
        CheckRow {
            required property int index
            required property string modelData
            title: modelData
            checked: index === root.current
            onToggled: if (index !== root.current) root.picked(index)
        }
    }
}
