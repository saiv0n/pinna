import QtQuick
import Earshot

SettingRow {
    id: root
    property real value
    property real from: 0
    property real to: 100
    property string leftLabel
    property string rightLabel
    property bool showValue: true
    signal committed(int value)

    Text {
        visible: root.showValue
        text: Math.round(slider.pressed ? slider.value : root.value)
        font.pixelSize: 14
        color: Theme.text2
        font.features: { "tnum": 1 }
    }

    below: Column {
        width: parent.width
        spacing: 2
        Slider {
            id: slider
            width: parent.width
            from: root.from
            to: root.to
            stepSize: 1
            value: root.value
            onCommitted: v => root.committed(Math.round(v))
        }
        Item {
            visible: root.leftLabel.length > 0
            width: parent.width
            height: 18
            Text { text: root.leftLabel; font: Theme.caption; color: Theme.text3 }
            Text { anchors.right: parent.right; text: root.rightLabel; font: Theme.caption; color: Theme.text3 }
        }
    }
}
