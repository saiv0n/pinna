import QtQuick
import Pinna

// Kartın içinde tam genişlik bir alan (kaydırıcı, grafik, seçici).
Item {
    id: root
    default property alias content: col.data
    property real padding: Theme.pad
    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight + 2 * padding
    Rectangle {
        visible: root.y > 0
        x: Theme.pad
        width: parent.width - 2 * Theme.pad
        height: 1
        color: Theme.line
    }
    Column {
        id: col
        x: root.padding
        y: root.padding
        width: parent.width - 2 * root.padding
        spacing: 8
    }
}
