import QtQuick
import Pinna

// Baş takibi verisinin canlı görünümü: yukarıdan bakılan bir baş ve ham değerler.
Item {
    id: root
    readonly property var v: Backend.head
    readonly property bool has: v && v.length >= 5
    // ölçek belgelerde yok, görülen en büyük değere göre normalleştir
    property real span: 1
    onVChanged: if (has) span = Math.max(span, Math.abs(v[0]), Math.abs(v[1]), Math.abs(v[2]))
    function n(i) { return has ? v[i] / span : 0 }
    implicitHeight: 150

    Rectangle {
        id: dial
        width: 130
        height: 130
        radius: 65
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        Item {
            anchors.centerIn: parent
            width: 70
            height: 80
            rotation: root.n(0) * 90
            transform: Rotation { origin.x: 35; origin.y: 40; axis { x: 1; y: 0; z: 0 } angle: root.n(1) * 50 }
            Rectangle { anchors.centerIn: parent; width: 58; height: 70; radius: 29; color: Theme.control; border.width: 1; border.color: Theme.border }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -2; width: 12; height: 14; radius: 6; color: Theme.accent }
            Rectangle { x: 0; y: 30; width: 8; height: 18; radius: 4; color: Theme.text3 }
            Rectangle { x: 62; y: 30; width: 8; height: 18; radius: 4; color: Theme.text3 }
        }
    }
    Column {
        x: dial.width + 20
        width: parent.width - x
        anchors.verticalCenter: dial.verticalCenter
        spacing: 6
        Repeater {
            model: [qsTr("Yönelim 1"), qsTr("Yönelim 2"), qsTr("Yönelim 3"), qsTr("Yatay ivme"), qsTr("Dikey ivme")]
            Row {
                required property int index
                required property string modelData
                spacing: 10
                Text { width: 90; text: parent.modelData; font: Theme.footnote; color: Theme.text2 }
                Text { text: root.has ? root.v[parent.index] : "–"; font.family: "monospace"; font.pixelSize: 12; color: Theme.text }
            }
        }
    }
}
