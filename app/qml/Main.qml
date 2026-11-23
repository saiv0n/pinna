import QtQuick
import QtQuick.Controls.Basic as C
import Pinna

Window {
    id: win
    // sabit boyut, Hyprland bu pencereyi kendiliğinden yüzdürür
    width: 440
    height: 780
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: true
    title: "Pinna"
    color: Theme.bg

    Shortcut { sequences: [StandardKey.Close]; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequences: ["Escape", "Alt+Left"]; enabled: stack.depth > 1; onActivated: stack.currentItem.back() }
    TapHandler { acceptedButtons: Qt.BackButton; onTapped: if (stack.depth > 1) stack.currentItem.back() }

    // bağlantı koparsa alt sayfada asılı kalma
    Connections {
        target: Store
        function onLiveChanged() { if (!Store.live) stack.pop(null, C.StackView.Immediate) }
    }

    Disconnected {
        anchors.fill: parent
        opacity: Store.live ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    C.StackView {
        id: stack
        anchors.fill: parent
        opacity: Store.live ? 1 : 0
        visible: opacity > 0
        scale: Store.live || Theme.reduce ? 1 : 0.98
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        initialItem: mainPage

        readonly property var curve: [0.2, 0.9, 0.25, 1, 1, 1]
        readonly property int dur: Theme.reduce ? 1 : 480

        // Animator'lar gerçek pencerede render iş parçacığında koşup opaklığı 0'da bırakıyordu
        pushEnter: Transition {
            NumberAnimation { property: "x"; from: Theme.reduce ? 0 : stack.width; to: 0; duration: stack.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: stack.curve }
            NumberAnimation { property: "opacity"; from: Theme.reduce ? 0 : 1; to: 1; duration: Theme.reduce ? 160 : 1 }
        }
        pushExit: Transition {
            NumberAnimation { property: "x"; from: 0; to: Theme.reduce ? 0 : -stack.width * 0.3; duration: stack.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: stack.curve }
            NumberAnimation { property: "opacity"; from: 1; to: Theme.reduce ? 0 : 0.6; duration: Theme.reduce ? 160 : stack.dur }
        }
        popEnter: Transition {
            NumberAnimation { property: "x"; from: Theme.reduce ? 0 : -stack.width * 0.3; to: 0; duration: stack.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: stack.curve }
            NumberAnimation { property: "opacity"; from: Theme.reduce ? 0 : 0.6; to: 1; duration: Theme.reduce ? 160 : stack.dur }
        }
        popExit: Transition {
            NumberAnimation { property: "x"; from: 0; to: Theme.reduce ? 0 : stack.width; duration: stack.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: stack.curve }
            NumberAnimation { property: "opacity"; from: 1; to: Theme.reduce ? 0 : 1; duration: Theme.reduce ? 160 : 1 }
        }
    }

    Component {
        id: mainPage
        MainPage {
            onOpen: (page, props) => stack.push(page, props)
        }
    }

    Banner { id: banner }
    Connections {
        target: Backend
        function onError(m) { banner.show(m) }
    }

    // ekran görüntüsü için doğrudan bir alt sayfayla açılabilsin
    Component.onCompleted: {
        const p = typeof pinnaPage === "string" ? pinnaPage : ""
        if (!p || !Store.live) return
        const pages = {
            left: ["HoldPage.qml", { side: "left" }],
            right: ["HoldPage.qml", { side: "right" }],
            access: ["AccessibilityPage.qml", {}],
            computer: ["ComputerPage.qml", {}],
            name: ["NamePage.qml", {}]
        }
        // gerçek geçişi denemek için animasyonlu aç
        if (pages[p]) Qt.callLater(() => stack.push(Qt.resolvedUrl(pages[p][0]), pages[p][1]))
    }
}
