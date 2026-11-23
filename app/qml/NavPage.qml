import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Shapes
import Pinna

// iOS sayfa iskeleti: üstte geri düğmeli gezinme çubuğu, altında kayan içerik.
Item {
    id: page
    property string title
    property string backTitle
    // ana sayfada başlık, büyük ad çubuğun altına kayınca belirir
    property real titleAfter: -1
    default property alias content: col.data
    readonly property alias flick: flick
    signal leaving()

    readonly property real barHeight: 50
    readonly property real scrolled: flick.contentY

    function back() {
        leaving()
        if (C.StackView.view && C.StackView.view.depth > 1)
            C.StackView.view.pop()
    }

    // yeni sayfa sağdan gelirken sol kenarında hafif gölge
    Rectangle {
        x: -14
        width: 14
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Theme.dark ? "#30000000" : "#12000000" }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height
        boundsBehavior: Flickable.DragOverBounds
        flickDeceleration: 2400
        maximumFlickVelocity: 4200

        Column {
            id: col
            x: Theme.margin
            width: flick.width - 2 * Theme.margin
            spacing: 28
            // çubuk başlangıçta boş; içerik altına kayınca belirir
            topPadding: page.barHeight + 8
            bottomPadding: 36
        }

        C.ScrollBar.vertical: C.ScrollBar {
            id: bar
            policy: C.ScrollBar.AsNeeded
            topPadding: page.barHeight + 2
            bottomPadding: 4
            rightPadding: 2
            contentItem: Rectangle {
                implicitWidth: 5
                radius: 2.5
                color: Theme.dark ? "#66ffffff" : "#59000000"
                opacity: bar.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: bar.active ? 100 : 500 } }
            }
            background: null
        }
    }

    Item {
        id: navBar
        width: parent.width
        height: page.barHeight

        Rectangle {
            anchors.fill: parent
            color: Theme.bar
            opacity: Math.max(0, Math.min(1, page.scrolled / 12))
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.separator
            opacity: Math.max(0, Math.min(1, page.scrolled / 12))
        }
        MouseArea { anchors.fill: parent }

        Text {
            anchors.centerIn: parent
            width: parent.width - 2 * Math.max(96, backBtn.width + 20)
            horizontalAlignment: Text.AlignHCenter
            text: page.title
            font: Theme.navTitle
            color: Theme.text
            elide: Text.ElideRight
            opacity: page.titleAfter < 0 ? 1 : Math.max(0, Math.min(1, (page.scrolled - page.titleAfter) / 16))
        }

        Item {
            id: backBtn
            visible: page.backTitle.length > 0
            x: 8
            width: backRow.width + 12
            height: parent.height
            activeFocusOnTab: true
            Keys.onReturnPressed: page.back()
            Keys.onSpacePressed: page.back()

            Row {
                id: backRow
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                opacity: backArea.pressed ? 0.35 : 1
                Behavior on opacity { NumberAnimation { duration: backArea.pressed ? 0 : 220 } }

                Shape {
                    width: 11
                    height: 19
                    anchors.verticalCenter: parent.verticalCenter
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 2.6
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 9.2; startY: 1.6
                        PathLine { x: 1.6; y: 9.5 }
                        PathLine { x: 9.2; y: 17.4 }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.backTitle
                    font: Theme.body
                    color: Theme.accent
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 130)
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 8
                color: "transparent"
                border.width: backBtn.activeFocus ? 2 : 0
                border.color: Theme.focus
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: page.back()
            }
        }
    }
}
