import QtQuick
import Pinna

// Başlığı olmayan kaydırıcı satırı; iki yanda ikon ya da yazı olabilir.
SettingRow {
    id: root
    property real value
    property real from: 0
    property real to: 100
    property string leftLabel
    property string rightLabel
    property bool speakers: false
    signal committed(int value)

    height: col.height + 22

    Column {
        id: col
        parent: root
        x: Theme.pad
        y: 11
        width: root.width - 2 * Theme.pad
        spacing: 2

        Row {
            width: parent.width
            spacing: 10
            Speaker { visible: root.speakers; waves: 0; anchors.verticalCenter: parent.verticalCenter }
            Slider {
                id: slider
                width: parent.width - (root.speakers ? 2 * 30 : 0)
                from: root.from
                to: root.to
                target: root.value
                enabled: root.enabled
                onCommitted: v => root.committed(Math.round(v))
            }
            Speaker { visible: root.speakers; waves: 2; anchors.verticalCenter: parent.verticalCenter }
        }
        Item {
            visible: root.leftLabel.length > 0
            width: parent.width
            height: 18
            Text { text: root.leftLabel; font: Theme.caption; color: Theme.text2 }
            Text { anchors.right: parent.right; text: root.rightLabel; font: Theme.caption; color: Theme.text2 }
        }
    }
}
