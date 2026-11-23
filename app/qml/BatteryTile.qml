import QtQuick
import QtQuick.Shapes
import Pinna

// Kenar çubuğundaki küçük pil göstergesi: ince çubuk, yüzde ve ad.
Item {
    id: root
    property string name
    property var level: null
    property bool charging: false
    // son bilinen değer, şu an okunmuyor
    property bool stale: false
    implicitHeight: 42

    readonly property bool known: level !== null && level !== undefined
    readonly property color tone: stale ? Theme.text3 : charging ? Theme.green
        : !known ? Theme.control : level <= 10 ? Theme.red : level <= Store.pref("lowBattery", 20) ? Theme.orange : Theme.green

    Accessible.role: Accessible.StaticText
    Accessible.name: name + ": " + (known ? level + "%" : qsTr("bilinmiyor")) + (charging ? ", " + qsTr("şarj oluyor") : "")

    Rectangle {
        width: parent.width
        height: 4
        radius: 2
        color: Theme.control
        Rectangle {
            height: parent.height
            radius: 2
            width: root.known ? Math.max(4, parent.width * root.level / 100) : 0
            color: root.tone
            Behavior on width { enabled: !Theme.reduce; NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
        }
    }
    Row {
        y: 10
        spacing: 2
        Text {
            text: root.known ? root.level + "%" : "-"
            font.family: Theme.family
            font.pixelSize: 13
            font.weight: 600
            font.features: { "tnum": 1 }
            color: root.known && !root.stale ? Theme.text : Theme.text3
        }
        Shape {
            visible: root.charging
            width: 9
            height: 13
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.green
                strokeColor: "transparent"
                startX: 6; startY: 0
                PathLine { x: 0.5; y: 7.5 }
                PathLine { x: 4; y: 7.5 }
                PathLine { x: 3; y: 13 }
                PathLine { x: 8.5; y: 5.5 }
                PathLine { x: 5; y: 5.5 }
                PathLine { x: 6; y: 0 }
            }
        }
    }
    Text {
        y: 27
        width: parent.width
        text: root.name
        font: Theme.caption
        color: Theme.text2
        elide: Text.ElideRight
    }
}
