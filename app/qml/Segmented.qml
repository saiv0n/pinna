import QtQuick
import Pinna

// Kayan göstergeli parçalı seçici.
Item {
    id: root
    property var model: []
    property int currentIndex: 0
    signal activated(int index)

    implicitHeight: 32
    height: implicitHeight
    activeFocusOnTab: true
    Keys.onLeftPressed: pick(Math.max(0, currentIndex - 1))
    Keys.onRightPressed: pick(Math.min(model.length - 1, currentIndex + 1))

    function pick(i) {
        if (i === currentIndex) return
        currentIndex = i
        activated(i)
    }

    readonly property real cell: model.length ? width / model.length : 0

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: Theme.segment
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.focus
    }

    Rectangle {
        visible: root.currentIndex >= 0
        x: root.currentIndex * root.cell + 2
        y: 2
        width: root.cell - 4
        height: root.height - 4
        radius: 7
        color: Theme.thumb
        Behavior on x { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: root.model
        Text {
            required property int index
            required property string modelData
            x: index * root.cell
            width: root.cell
            height: root.height
            text: modelData
            font: index === root.currentIndex ? Theme.label : Theme.body
            color: index === root.currentIndex ? Theme.text : Theme.text2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(parent.index)
            }
        }
    }
}
