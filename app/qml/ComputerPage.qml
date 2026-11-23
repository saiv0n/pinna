import QtQuick
import Pinna

Page {
    id: page
    property Item confirm
    title: qsTr("Bu Bilgisayar")

    Section {
        title: qsTr("Medya")
        enabled: Backend.daemon
        Setting {
            title: qsTr("Kulaklık çıkınca duraklat")
            Switch { checked: Store.pref("autoPause", true); onToggled: v => Backend.setPref("autoPause", v) }
        }
        Setting {
            title: qsTr("Takınca devam ettir")
            Switch { checked: Store.pref("autoResume", true); onToggled: v => Backend.setPref("autoResume", v) }
        }
    }

    Section {
        title: qsTr("Bildirimler")
        enabled: Backend.daemon
        Setting {
            title: qsTr("Bağlanınca kart göster")
            Switch { checked: Store.pref("popup", true); onToggled: v => Backend.setPref("popup", v) }
        }
        Setting {
            title: qsTr("Kutu açılınca pili göster")
            subtitle: qsTr("Bağlı değilken kutunun yayınını dinler.")
            Switch { checked: Store.pref("caseScan", true); onToggled: v => Backend.setPref("caseScan", v) }
        }
        Setting {
            title: qsTr("Pil azalınca uyar")
            Dropdown {
                visible: Store.pref("lowBatteryNotify", true)
                readonly property var steps: [10, 15, 20, 30]
                model: steps.map(n => qsTr("%1% altında").arg(n))
                currentIndex: Math.max(0, steps.indexOf(Store.pref("lowBattery", 20)))
                onPicked: i => Backend.setPref("lowBattery", steps[i])
            }
            Switch { checked: Store.pref("lowBatteryNotify", true); onToggled: v => Backend.setPref("lowBatteryNotify", v) }
        }
        Setting {
            title: qsTr("Şarj bitince bildir")
            Switch { checked: Store.pref("chargedNotify", true); onToggled: v => Backend.setPref("chargedNotify", v) }
        }
    }

    Section {
        title: qsTr("Uygulama")
        Setting {
            title: qsTr("Dil")
            Dropdown {
                readonly property var codes: ["", "tr", "en"]
                model: [qsTr("Sistem dili"), "Türkçe", "English"]
                currentIndex: Math.max(0, codes.indexOf(Backend.language))
                onPicked: i => Backend.language = codes[i]
            }
        }
        Setting {
            title: qsTr("Kapatınca tepside kalsın")
            subtitle: Backend.trayAvailable ? "" : qsTr("Masaüstünde sistem tepsisi bulunamadı.")
            enabled: Backend.trayAvailable
            Switch { checked: Backend.closeToTray; onToggled: v => Backend.closeToTray = v }
        }
        Setting {
            title: qsTr("Oturum açılınca tepside başlat")
            Switch { checked: Backend.autostart; onToggled: v => Backend.autostart = v }
        }
    }

    Section {
        title: qsTr("Bluetooth")
        footer: qsTr("Bazı özellikler kulaklığın karşısında bir Apple aygıtı görmek istiyor. Bu ayar BlueZ'e Apple kimliği verir; sistem dosyası değiştiği için parola sorulur.")
        Setting {
            title: qsTr("Apple aygıt kimliği (DeviceID)")
            subtitle: Backend.deviceIdOk ? qsTr("/etc/bluetooth/main.conf içinde ayarlı.") : qsTr("Ayarlı değil.")
            Button {
                visible: !Backend.deviceIdOk
                text: qsTr("Ayarla…")
                onClicked: page.confirm.ask(qsTr("DeviceID eklensin mi?"),
                    qsTr("Şu komut yönetici yetkisiyle çalışacak. Bluetooth yeniden başlayacağı için kulaklık bir an kopar."),
                    Backend.deviceIdCommand, qsTr("Çalıştır"), () => Backend.setupDeviceId())
            }
        }
    }

    Section {
        title: qsTr("Servis")
        Setting {
            title: Backend.daemon ? qsTr("pinnad çalışıyor") : qsTr("pinnad çalışmıyor")
            subtitle: qsTr("Kulaklıkla konuşan arka plan servisi. Pencere kapalıyken de çalışır.")
            Button {
                text: Backend.daemon ? qsTr("Yeniden Başlat") : qsTr("Başlat")
                onClicked: Backend.startDaemon()
            }
        }
        Setting {
            title: qsTr("Hata ayıklama günlüğü")
            subtitle: qsTr("Servis günlüğünü ve durumu İndirilenler klasörüne bir dosya olarak kaydeder.")
            Button { text: qsTr("Dışa Aktar"); onClicked: Backend.exportLog() }
        }
    }
}
