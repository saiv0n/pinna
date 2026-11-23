import QtQuick
import Pinna

// Live head tracking view. The first samples count as looking straight ahead.
Item {
    id: root
    readonly property var v: Backend.head
    property var samples: []
    property var zero: null
    property real pitch: 0
    property real yaw: 0
    implicitHeight: 168

    function reset() { samples = []; zero = null; pitch = 0; yaw = 0 }
    onVChanged: {
        if (!v || v.length < 3) return
        if (!zero) {
            const s = samples.concat([[v[0], v[1], v[2]]])
            samples = s
            if (s.length >= 10)
                zero = [1, 2].map(i => s.reduce((a, r) => a + r[i], 0) / s.length)
            return
        }
        const o2 = v[1] - zero[0], o3 = v[2] - zero[1]
        pitch = (o2 + o3) / 2 / 32000 * 180
        yaw = (o2 - o3) / 2 / 32000 * 180
    }

    Rectangle {
        id: stage
        width: 150
        height: 150
        radius: 75
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        Item {
            id: head
            anchors.centerIn: parent
            width: 72
            height: 88
            transform: [
                Rotation { origin.x: 36; origin.y: 44; axis { x: 0; y: 1; z: 0 } angle: Math.max(-80, Math.min(80, root.yaw)) },
                Rotation { origin.x: 36; origin.y: 44; axis { x: 1; y: 0; z: 0 } angle: Math.max(-60, Math.min(60, -root.pitch)) }
            ]
            Behavior on x { enabled: false }
            Rectangle { anchors.fill: parent; radius: 36; color: Theme.control; border.width: 1; border.color: Theme.border }
            Rectangle { x: 20; y: 34; width: 8; height: 8; radius: 4; color: Theme.text }
            Rectangle { x: 44; y: 34; width: 8; height: 8; radius: 4; color: Theme.text }
            Rectangle { x: 26; y: 60; width: 20; height: 4; radius: 2; color: Theme.text2 }
            Rectangle { x: -6; y: 36; width: 8; height: 18; radius: 4; color: "#ffffff"; border.width: 1; border.color: Theme.border }
            Rectangle { x: 70; y: 36; width: 8; height: 18; radius: 4; color: "#ffffff"; border.width: 1; border.color: Theme.border }
        }
    }

    Column {
        x: stage.width + 28
        anchors.verticalCenter: stage.verticalCenter
        spacing: 10
        Text {
            text: !root.zero ? qsTr("Look straight ahead, calibrating…") : qsTr("Turn or tilt your head")
            font: Theme.body
            color: Theme.text2
        }
        Row {
            spacing: 24
            Column {
                Text { text: qsTr("Turn"); font: Theme.footnote; color: Theme.text2 }
                Text { text: Math.round(root.yaw) + "°"; font: Theme.title; color: Theme.text }
            }
            Column {
                Text { text: qsTr("Tilt"); font: Theme.footnote; color: Theme.text2 }
                Text { text: Math.round(root.pitch) + "°"; font: Theme.title; color: Theme.text }
            }
        }
        Button { text: qsTr("Recenter"); enabled: !!root.zero; onClicked: root.reset() }
    }
}
