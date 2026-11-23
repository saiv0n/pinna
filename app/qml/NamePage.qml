import QtQuick
import QtQuick.Shapes
import Pinna

// Ad değiştirme. Enter'a basınca ya da geri dönünce kaydedilir.
NavPage {
    id: page
    title: "Ad"
    backTitle: Store.name

    function save() {
        const t = field.text.trim()
        if (t.length && t !== Store.name)
            Backend.rename(t)
    }
    onLeaving: save()

    Group {
        SettingRow {
            id: nameRow
            TextInput {
                id: field
                parent: nameRow
                x: Theme.pad
                width: parent.width - 2 * Theme.pad - 30
                anchors.verticalCenter: parent.verticalCenter
                text: Store.name
                font: Theme.body
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                maximumLength: 32
                focus: true
                Component.onCompleted: { forceActiveFocus(); selectAll() }
                onAccepted: { page.save(); page.back() }
            }
            Rectangle {
                visible: field.text.length > 0
                width: 18
                height: 18
                radius: 9
                color: Theme.text3
                Shape {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    ShapePath {
                        strokeColor: Theme.group
                        strokeWidth: 1.8
                        capStyle: ShapePath.RoundCap
                        startX: 1; startY: 1
                        PathLine { x: 7; y: 7 }
                        PathMove { x: 7; y: 1 }
                        PathLine { x: 1; y: 7 }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { field.text = ""; field.forceActiveFocus() }
                }
            }
        }
    }
}
