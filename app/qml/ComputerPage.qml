import QtQuick
import Pinna

Page {
    id: page
    property Item confirm
    title: qsTr("This Computer")

    Section {
        title: qsTr("Media")
        enabled: Backend.daemon
        Setting {
            title: qsTr("Pause when removed")
            Switch { checked: Store.pref("autoPause", true); onToggled: v => Backend.setPref("autoPause", v) }
        }
        Setting {
            title: qsTr("Resume when put back in")
            Switch { checked: Store.pref("autoResume", true); onToggled: v => Backend.setPref("autoResume", v) }
        }
    }

    Section {
        title: qsTr("Notifications")
        enabled: Backend.daemon
        Setting {
            title: qsTr("Show a card on connect")
            Switch { checked: Store.pref("popup", true); onToggled: v => Backend.setPref("popup", v) }
        }
        Setting {
            title: qsTr("Show battery when case opens")
            subtitle: qsTr("Listens for the case broadcast while not connected.")
            Switch { checked: Store.pref("caseScan", true); onToggled: v => Backend.setPref("caseScan", v) }
        }
        Setting {
            title: qsTr("Low battery warning")
            Dropdown {
                visible: Store.pref("lowBatteryNotify", true)
                readonly property var steps: [10, 15, 20, 30]
                model: steps.map(n => qsTr("Below %1%").arg(n))
                currentIndex: Math.max(0, steps.indexOf(Store.pref("lowBattery", 20)))
                onPicked: i => Backend.setPref("lowBattery", steps[i])
            }
            Switch { checked: Store.pref("lowBatteryNotify", true); onToggled: v => Backend.setPref("lowBatteryNotify", v) }
        }
        Setting {
            title: qsTr("Notify when fully charged")
            Switch { checked: Store.pref("chargedNotify", true); onToggled: v => Backend.setPref("chargedNotify", v) }
        }
    }

    Section {
        title: qsTr("Application")
        Setting {
            title: qsTr("Language")
            Dropdown {
                readonly property var codes: ["", "tr", "en"]
                model: [qsTr("System language"), "Türkçe", "English"]
                currentIndex: Math.max(0, codes.indexOf(Backend.language))
                onPicked: i => Backend.language = codes[i]
            }
        }
        Setting {
            title: qsTr("Keep in tray when closed")
            subtitle: Backend.trayAvailable ? "" : qsTr("No system tray was found on this desktop.")
            enabled: Backend.trayAvailable
            Switch { checked: Backend.closeToTray; onToggled: v => Backend.closeToTray = v }
        }
        Setting {
            title: qsTr("Start in tray at login")
            Switch { checked: Backend.autostart; onToggled: v => Backend.autostart = v }
        }
    }

    Section {
        title: qsTr("Bluetooth")
        footer: qsTr("Some features only work when the headphones see an Apple device. This gives BlueZ an Apple vendor ID; it edits a system file, so you will be asked for your password.")
        Setting {
            title: qsTr("Apple device ID (DeviceID)")
            subtitle: Backend.deviceIdOk ? qsTr("Set in /etc/bluetooth/main.conf.") : qsTr("Not set.")
            Button {
                visible: !Backend.deviceIdOk
                text: qsTr("Set Up…")
                onClicked: page.confirm.ask(qsTr("Add DeviceID?"),
                    qsTr("This command will run as administrator. Bluetooth restarts, so the headphones will disconnect briefly."),
                    Backend.deviceIdCommand, qsTr("Run"), () => Backend.setupDeviceId())
            }
        }
    }

    Section {
        title: qsTr("Service")
        Setting {
            title: Backend.daemon ? qsTr("pinnad is running") : qsTr("pinnad is not running")
            subtitle: qsTr("The background service that talks to the headphones. It keeps running when the window is closed.")
            Button {
                text: Backend.daemon ? qsTr("Restart") : qsTr("Start")
                onClicked: Backend.startDaemon()
            }
        }
        Setting {
            title: qsTr("Debug log")
            subtitle: qsTr("Saves the service log and current state to a file in your Downloads folder.")
            Button { text: qsTr("Export"); onClicked: Backend.exportLog() }
        }
    }
}
