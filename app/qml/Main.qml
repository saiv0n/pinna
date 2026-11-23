import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

Window {
    id: win
    // sabit boyut, Hyprland bu pencereyi kendiliğinden yüzdürür
    width: 440
    height: 800
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: true
    title: "Pinna"
    color: Theme.bg

    readonly property var s: Backend.state
    readonly property var set: s.settings || ({})
    readonly property var prefs: s.prefs || ({})
    readonly property bool live: Backend.daemon && !!s.connected

    function setting(key, fallback) {
        return set[key] !== undefined ? set[key] : fallback
    }

    // pencerenin üstünde çok hafif bir ton geçişi; çizimin oturduğu zemin
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        height: 360
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.bgTop }
            GradientStop { position: 1; color: Theme.bg }
        }
    }

    Shortcut { sequences: [StandardKey.Close]; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }

    Disconnected {
        visible: !win.live
        anchors.centerIn: parent
        width: parent.width - 64
        s: win.s
        daemon: Backend.daemon
    }

    C.ScrollView {
        id: scroll
        visible: win.live
        anchors.fill: parent
        contentWidth: availableWidth
        C.ScrollBar.horizontal.policy: C.ScrollBar.AlwaysOff

        Column {
            id: page
            x: 20
            width: scroll.availableWidth - 40
            spacing: 26
            topPadding: 26
            bottomPadding: 32

            Hero {
                s: win.s
                onRenameRequested: name => Backend.rename(name)
            }

            Column {
                width: parent.width
                spacing: 8
                visible: !!win.s.mode
                ModeSwitch {
                    mode: win.s.mode || ""
                    onPicked: m => Backend.setMode(m)
                }
                Group {
                    visible: win.s.mode === "adaptive"
                    footer: "Uyarlanabilir modda ne kadar ortam sesinin içeri gireceğini belirler."
                    SliderRow {
                        title: "Gürültü Azaltma Düzeyi"
                        value: win.setting("adaptiveStrength", 50)
                        leftLabel: "Daha çok ortam sesi"
                        rightLabel: "Daha az ortam sesi"
                        onCommitted: v => Backend.setSetting("adaptiveStrength", v)
                    }
                }
            }

            Group {
                title: "Ses"
                ToggleRow {
                    title: "Konuşma Algılama"
                    subtitle: "Konuşmaya başlayınca medyanın sesini kısar, ortam sesini açar."
                    checked: win.setting("conversationAwareness", false)
                    onToggled: v => Backend.setSetting("conversationAwareness", v)
                }
                ToggleRow {
                    title: "Kişiselleştirilmiş Ses Düzeyi"
                    subtitle: "Ortama göre ses düzeyini kendiliğinden ayarlar."
                    checked: win.setting("adaptiveVolume", false)
                    onToggled: v => Backend.setSetting("adaptiveVolume", v)
                }
                ToggleRow {
                    title: "Tek AirPod ile Gürültü Engelleme"
                    checked: win.setting("oneBudAnc", false)
                    onToggled: v => Backend.setSetting("oneBudAnc", v)
                }
            }

            Group {
                title: "Basılı Tutma"
                ChoiceRow {
                    title: "Sol AirPod"
                    options: ["Gürültü Kontrolü", "Siri"]
                    current: win.setting("holdLeft", 1) === 5 ? 1 : 0
                    onPicked: i => Backend.setSetting("holdLeft", i === 1 ? 5 : 1)
                }
                ChoiceRow {
                    title: "Sağ AirPod"
                    options: ["Gürültü Kontrolü", "Siri"]
                    current: win.setting("holdRight", 1) === 5 ? 1 : 0
                    onPicked: i => Backend.setSetting("holdRight", i === 1 ? 5 : 1)
                }
            }

            Group {
                title: "Basılı Tutunca Geçilecek Modlar"
                footer: "En az iki mod seçili kalmalı."
                Repeater {
                    model: [
                        { bit: 1, label: "Kapalı" },
                        { bit: 2, label: "Gürültü Engelleme" },
                        { bit: 8, label: "Uyarlanabilir" },
                        { bit: 4, label: "Şeffaf" }
                    ]
                    CheckRow {
                        required property var modelData
                        readonly property int mask: win.setting("listeningCycle", 14)
                        readonly property int count: [1, 2, 4, 8].filter(b => mask & b).length
                        title: modelData.label
                        checked: (mask & modelData.bit) !== 0
                        locked: count <= 2
                        onToggled: v => Backend.setSetting("listeningCycle", v ? (mask | modelData.bit) : (mask & ~modelData.bit))
                    }
                }
            }

            Group {
                title: "Kontroller"
                ToggleRow {
                    title: "Ses Düzeyini Kaydırarak Ayarla"
                    subtitle: "Sapın üzerinde parmağını yukarı aşağı kaydır."
                    checked: win.setting("volumeSwipe", true)
                    onToggled: v => Backend.setSetting("volumeSwipe", v)
                }
                ChoiceRow {
                    visible: win.setting("volumeSwipe", true)
                    title: "Kaydırma Aralığı"
                    options: ["Varsayılan", "Daha Uzun", "En Uzun"]
                    current: win.setting("volumeSwipeInterval", 0)
                    onPicked: i => Backend.setSetting("volumeSwipeInterval", i)
                }
                ChoiceRow {
                    title: "Basma Hızı"
                    options: ["Varsayılan", "Yavaş", "En Yavaş"]
                    current: win.setting("pressSpeed", 0)
                    onPicked: i => Backend.setSetting("pressSpeed", i)
                }
                ChoiceRow {
                    title: "Basılı Tutma Süresi"
                    options: ["Varsayılan", "Daha Uzun", "En Uzun"]
                    current: win.setting("holdDuration", 0)
                    onPicked: i => Backend.setSetting("holdDuration", i)
                }
            }

            Group {
                title: "Kutu ve Algılama"
                SliderRow {
                    title: "Kutu Hoparlörü Ses Düzeyi"
                    value: win.setting("chimeVolume", 80)
                    onCommitted: v => Backend.setSetting("chimeVolume", v)
                }
                ToggleRow {
                    title: "Uyku Algılama"
                    subtitle: "Uykuya daldığını fark edince medyayı duraklatır."
                    checked: win.setting("sleepDetection", false)
                    onToggled: v => Backend.setSetting("sleepDetection", v)
                }
            }

            Group {
                title: "Bu Bilgisayarda"
                ToggleRow {
                    title: "Çıkarınca Duraklat"
                    subtitle: "Bir AirPod'u kulağından çıkarınca çalan medya durur."
                    checked: win.prefs.autoPause !== false
                    onToggled: v => Backend.setPref("autoPause", v)
                }
                ToggleRow {
                    title: "Takınca Devam Et"
                    checked: win.prefs.autoResume !== false
                    onToggled: v => Backend.setPref("autoResume", v)
                }
                ToggleRow {
                    title: "Konuşurken Sesi Kıs"
                    subtitle: "Konuşma Algılama açıkken bilgisayarın sesini de kısar."
                    checked: win.prefs.duckOnSpeech !== false
                    onToggled: v => Backend.setPref("duckOnSpeech", v)
                }
                SliderRow {
                    visible: win.prefs.duckOnSpeech !== false
                    title: "Kısılınca Kalan Ses"
                    value: win.prefs.duckLevel !== undefined ? win.prefs.duckLevel : 25
                    onCommitted: v => Backend.setPref("duckLevel", v)
                }
                ToggleRow {
                    title: "Düşük Pil Bildirimi"
                    checked: win.prefs.lowBatteryNotify !== false
                    onToggled: v => Backend.setPref("lowBatteryNotify", v)
                }
                ToggleRow {
                    title: "Bağlanınca Kart Göster"
                    checked: win.prefs.popup !== false
                    onToggled: v => Backend.setPref("popup", v)
                }
                ToggleRow {
                    title: "Kutu Açılınca Algıla"
                    subtitle: "Bağlı değilken Bluetooth ile kutuyu dinler. Pili biraz daha fazla kullanır."
                    checked: win.prefs.caseScan !== false
                    onToggled: v => Backend.setPref("caseScan", v)
                }
            }

            Group {
                title: "Hakkında"
                InfoRow { title: "Model"; value: (win.s.modelName || "") + (win.s.model ? "  " + win.s.model : "") }
                InfoRow { title: "Seri Numarası"; value: win.s.serial || "—" }
                InfoRow { title: "Sol AirPod"; value: win.s.serialLeft || "—" }
                InfoRow { title: "Sağ AirPod"; value: win.s.serialRight || "—" }
                InfoRow { title: "Yazılım Sürümü"; value: win.s.firmware || "—" }
                InfoRow { title: "Bluetooth Adresi"; value: win.s.address || "—" }
            }

            Group {
                SettingRow {
                    title: "Bağlantıyı Kes"
                    titleColor: Theme.red
                    clickable: true
                    onClicked: Backend.disconnectDevice()
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Kulaklık görseli Jed Falcone'un AirPods Pro modelinden (CC BY 4.0).\nPinna'nın Apple ile bir bağı yoktur."
                font: Theme.caption
                color: Theme.text3
                lineHeight: 1.2
            }
        }
    }

    Toast { id: toast }
    Connections {
        target: Backend
        function onError(m) { toast.show(m) }
    }
}
