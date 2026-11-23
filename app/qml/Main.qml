import QtQuick
import QtQuick.Layouts
import Pinna

Window {
    id: win
    width: typeof pinnaWidth === "number" && pinnaWidth > 0 ? pinnaWidth : 900
    height: 620
    minimumWidth: 720
    minimumHeight: 520
    visible: false
    title: "Pinna"
    color: Theme.bg

    property int page: 0
    readonly property var pages: [qsTr("General"), qsTr("Noise Control"), qsTr("Controls"), qsTr("Audio"),
                                  qsTr("Accessibility"), qsTr("This Computer"), qsTr("About")]
    function go(i, focusPage) {
        page = i
        if (focusPage) stack.children[i].forceActiveFocus()
    }

    // stay in the tray on close; quit when there is no tray or it is not wanted
    onClosing: close => {
        if (Backend.trayAvailable && Backend.closeToTray) {
            close.accepted = false
            win.hide()
            // do not keep UI memory around while in the tray
            Backend.releaseWindow()
        } else {
            Qt.quit()
        }
    }

    // what the content area shows; This Computer and About always open
    readonly property bool devicePage: page <= 4
    readonly property string blocker: !devicePage ? ""
        : !Backend.daemon ? "service"
        : Store.s.adapter === false ? "bluetooth"
        : Store.devices.length === 0 && !Store.s.address ? "setup"
        : ""

    Repeater {
        model: 7
        Item {
            required property int index
            Shortcut { sequence: "Ctrl+" + (index + 1); onActivated: win.go(index, true) }
        }
    }
    Shortcut { sequences: [StandardKey.Close]; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+PgDown"; onActivated: win.go((win.page + 1) % 7, true) }
    Shortcut { sequence: "Ctrl+PgUp"; onActivated: win.go((win.page + 6) % 7, true) }

    // the sidebar reads the last known case battery from here too
    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Backend.daemon
        onTriggered: Backend.loadHistory()
    }
    Connections { target: Store; function onLiveChanged() { Backend.loadHistory() } }
    // PINNA_DEMO=mode or page, with PINNA_STATE, changes the mode or page after a second
    // so transitions can be captured mid-flight
    Timer {
        running: typeof pinnaDemo === "string" && (pinnaDemo === "mode" || pinnaDemo === "page")
        interval: 1000
        onTriggered: pinnaDemo === "page" ? win.go(1) : Backend.setMode(Store.s.mode === "transparency" ? "anc" : "transparency")
    }

    Sidebar {
        id: side
        height: parent.height
        pages: win.pages
        current: win.page
        onPicked: i => win.go(i)
        onPair: { win.go(0); general.startPairing() }
    }

    Item {
        x: side.width
        width: parent.width - side.width
        height: parent.height

        // an honest banner on top when the service or connection is missing
        Rectangle {
            id: strip
            width: parent.width
            height: visible ? 40 : 0
            visible: win.blocker === "" && Backend.daemon && !Store.live && win.page >= 1 && win.page <= 4
            color: Theme.dark ? "#2a2620" : "#fff6e5"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            Text {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - stripButton.width - 40
                elide: Text.ElideRight
                text: qsTr("%1 is not connected. These settings can be changed once it connects.").arg(Store.name)
                font: Theme.body
                color: Theme.text
            }
            Button {
                id: stripButton
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Connect")
                onClicked: Backend.connectDevice()
            }
        }

        StackLayout {
            id: stack
            y: strip.height
            width: parent.width
            height: parent.height - y
            currentIndex: win.page
            visible: win.blocker === ""
            // a short rise and fade on page change; skipped with reduced motion
            transform: Translate { id: shift }
            onCurrentIndexChanged: if (!Theme.reduce) enter.restart()
            ParallelAnimation {
                id: enter
                NumberAnimation { target: stack; property: "opacity"; from: 0.4; to: 1; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: shift; property: "y"; from: 10; to: 0; duration: 260; easing.type: Easing.OutCubic }
            }
            GeneralPage { id: general; confirm: confirm }
            NoisePage {}
            ControlsPage {}
            AudioPage {}
            AccessibilityPage {}
            ComputerPage { confirm: confirm }
            AboutPage {}
        }

        StatusView {
            anchors.fill: parent
            visible: win.blocker === "service"
            title: qsTr("The Pinna service isn't running")
            text: qsTr("The background service that talks to your headphones is stopped. Start it to use all settings again.")
            action: qsTr("Start Service")
            onTriggered: Backend.startDaemon()
        }
        StatusView {
            anchors.fill: parent
            visible: win.blocker === "bluetooth"
            title: qsTr("Bluetooth is off")
            text: qsTr("Bluetooth needs to be on to connect to your AirPods and change their settings.")
            action: qsTr("Turn On Bluetooth")
            onTriggered: Backend.powerOn()
        }
        Onboarding {
            anchors.fill: parent
            visible: win.blocker === "setup"
        }
    }

    Confirm { id: confirm }
    Toast { id: toast }
    Connections {
        target: Backend
        function onError(code, m) {
            const e = {
                "not-connected": [qsTr("Headphones not connected"), qsTr("This setting can only change while the headphones are connected."), qsTr("Connect"), () => Backend.connectDevice()],
                "bluetooth-off": [qsTr("Bluetooth is off"), qsTr("Turn on Bluetooth to reach your headphones."), qsTr("Turn On Bluetooth"), () => Backend.powerOn()],
                "unreachable": [qsTr("Couldn't reach the headphones"), qsTr("Take them out of the case or open the lid, and keep them near the computer."), qsTr("Try Again"), () => Backend.connectDevice()],
                "busy": [qsTr("Bluetooth is busy"), qsTr("Another operation is in progress. Try again in a few seconds.")],
                "service": [qsTr("Couldn't reach the service"), qsTr("The Pinna service didn't respond."), qsTr("Start Service"), () => Backend.startDaemon()],
                "pair-failed": [qsTr("Pairing didn't finish"), qsTr("With the lid open, hold the button on the back of the case until the light flashes white."), qsTr("Search Again"), () => Backend.discover(true)],
                "audio": [qsTr("Audio setting didn't change"), qsTr("PipeWire didn't accept the request for these headphones. Take them out and put them back in.")],
                "invalid": [qsTr("That value can't be used"), m],
                "no-device": [qsTr("No paired headphones"), qsTr("Pair your AirPods with this computer first."), qsTr("Pair"), () => { win.go(0); Backend.discover(true) }],
                "deviceid": [qsTr("DeviceID wasn't added"), m],
                "file": [qsTr("Couldn't save the log"), m]
            }[code] || [qsTr("Something went wrong"), m]
            toast.show(e[0], e[1], true, e[2], e[3])
        }
        function onNotice(m) { toast.show(m, "", false) }
    }

    // allow opening on a given page for screenshots
    Component.onCompleted: {
        const p = typeof pinnaPage === "string" ? parseInt(pinnaPage) : NaN
        if (!isNaN(p)) page = p
    }
}
