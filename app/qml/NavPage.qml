import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Shapes
import Pinna

// iOS sayfa iskeleti: üstte geri düğmeli gezinme çubuğu, altında kayan içerik.
Item {
    id: page
    property string title
    property string backTitle
    // iOS büyük başlığı: kaydırınca çubuktaki küçük başlığa dönüşür
    property bool large: false
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
            topPadding: page.barHeight + (page.large ? 0 : 8)
            bottomPadding: 36

            Text {
                id: bigTitle
                visible: page.large
                leftPadding: 2
                bottomPadding: 6
                text: page.title
                font: Theme.large
                color: Theme.text
                // yukarı kaydırınca solar, aşağı çekince iOS'taki gibi hafifçe büyür
                opacity: Math.max(0, 1 - page.scrolled / 28)
                transformOrigin: Item.Left
                scale: 1 + Math.max(0, -page.scrolled) / 500
            }
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
            opacity: !page.large ? 1 : Math.max(0, Math.min(1, (page.scrolled - 22) / 14))
        }

        Rectangle {
            id: backBtn
            visible: page.backTitle.length > 0
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 18
            color: Theme.dark ? "#2c2c2e" : "#ffffff"
            border.width: backBtn.activeFocus ? 2 : (Theme.dark ? 0 : 0.5)
            border.color: backBtn.activeFocus ? Theme.focus : "#14000000"
            scale: backArea.pressed ? 0.9 : 1
            activeFocusOnTab: true
            Keys.onReturnPressed: page.back()
            Keys.onSpacePressed: page.back()
            Behavior on scale { enabled: !Theme.reduce; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.005 } }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: -1.5
                z: -1
                radius: height / 2
                color: Theme.dark ? "#00000000" : "#12000000"
            }
            Shape {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                width: 10
                height: 17
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.text
                    strokeWidth: 2.3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: 8.2; startY: 1.5
                    PathLine { x: 1.6; y: 8.5 }
                    PathLine { x: 8.2; y: 15.5 }
                }
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: page.back()
            }
        }
    }
}
