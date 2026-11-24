import QtQuick
import QtQuick.Layouts
import Pinna

// One row: name and description on the left, the control on the right.
Item {
    id: root
    property string title
    property string subtitle
    property alias titleColor: label.color
    property bool clickable: false
    default property alias content: slot.data
    signal clicked()
    signal menu(real x, real y)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.row, texts.implicitHeight + 16, slot.implicitHeight + 12)
    opacity: enabled ? 1 : 0.5

    Rectangle {
        visible: root.y > 0
        x: Theme.pad
        width: parent.width - 2 * Theme.pad
        height: 1
        color: Theme.line
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.radius - 1
        visible: root.clickable && area.containsMouse
        color: Theme.hover
    }
    Column {
        id: texts
        x: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2 * Theme.pad - (slot.implicitWidth > 0 ? slot.implicitWidth + 16 : 0)
        spacing: 1
        Text {
            id: label
            width: parent.width
            text: root.title
            font: Theme.body
            color: Theme.text
            elide: Text.ElideRight
        }
        Text {
            visible: !!root.subtitle
            width: parent.width
            text: root.subtitle
            font: Theme.footnote
            color: Theme.text2
            wrapMode: Text.Wrap
        }
    }
    // Row aligns to the top; keep controls of different heights centered
    RowLayout {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
    // controls in the row are read out with the row's title
    Component.onCompleted: {
        for (const c of slot.children)
            if (c.label !== undefined && c.label === "")
                c.label = Qt.binding(() => root.title)
    }
    MouseArea {
        id: area
        z: -1
        anchors.fill: parent
        hoverEnabled: root.clickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => m.button === Qt.RightButton ? root.menu(m.x, m.y) : root.clickable && root.clicked()
    }
}
