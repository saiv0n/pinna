pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

// Caelestia barı için: AirPods bağlıyken simge, en düşük pil ve dinleme modu.
// Sol tık modlar arasında geçer, sağ tık Pinna'yı açar.
Item {
    id: root

    required property color colour
    property var st: ({})
    readonly property bool on: !!st.connected
    readonly property var bat: st.battery || ({})
    readonly property int level: {
        const l = [bat.left, bat.right].filter(c => c && c.level !== null && c.level !== undefined).map(c => c.level);
        return l.length ? Math.min(...l) : -1;
    }

    visible: on
    implicitWidth: layout.implicitWidth
    implicitHeight: on ? layout.implicitHeight : 0

    Process {
        id: watch
        running: true
        command: ["pinnactl", "watch"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.st = JSON.parse(data);
                } catch (e) {}
            }
        }
        // servis yeniden başlarsa bağlantıyı tazele
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 3000
        onTriggered: watch.running = true
    }

    Process {
        id: cycle
        command: ["pinnactl", "cycle"]
    }

    ColumnLayout {
        id: layout
        spacing: Tokens.spacing.small / 2

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            animate: true
            text: root.st.mode === "anc" ? "noise_control_on"
                : root.st.mode === "transparency" ? "hearing"
                : root.st.mode === "adaptive" ? "noise_aware"
                : "earbuds"
            color: root.colour
            fontStyle: Tokens.font.icon.medium
            fill: 1
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.level >= 0
            text: root.level
            color: root.level <= 20 ? Colours.palette.m3error : root.colour
            font: Tokens.font.body.builders.small.scale(0.85).build()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton)
                Quickshell.execDetached(["pinna"]);
            else
                cycle.running = true;
        }
    }
}
