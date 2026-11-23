import QtQuick
import Pinna

// Son 24 saatin pil çizgileri. Veri yoksa ya da kulaklık bağlı değilken boşluk bırakılır.
Item {
    id: root
    property var rows: Backend.history
    readonly property var series: [
        { i: 1, name: qsTr("Sol"), color: Theme.accent },
        { i: 2, name: qsTr("Sağ"), color: Theme.green },
        { i: 3, name: qsTr("Kutu"), color: Theme.orange }
    ]
    implicitHeight: 170
    onRowsChanged: canvas.requestPaint()
    Connections { target: Theme; function onDarkChanged() { canvas.requestPaint() } }

    Canvas {
        id: canvas
        x: 28
        width: parent.width - 28
        height: parent.height - 34
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const now = Date.now() / 1000, from = now - 86400
            ctx.strokeStyle = Theme.line
            ctx.lineWidth = 1
            for (const g of [0, 0.5, 1]) {
                const y = Math.round(h - g * (h - 4)) - 0.5
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
            }
            const rows = root.rows || []
            for (const s of root.series) {
                ctx.strokeStyle = s.color
                ctx.lineWidth = 1.8
                ctx.lineJoin = "round"
                ctx.beginPath()
                let open = false, last = 0
                for (const r of rows) {
                    const v = r[s.i]
                    // 20 dakikadan uzun boşlukta çizgi koparılır
                    if (v < 0 || (open && r[0] - last > 1200)) { open = false; if (v < 0) continue }
                    const x = (r[0] - from) / 86400 * w
                    const y = h - v / 100 * (h - 4)
                    if (open) ctx.lineTo(x, y); else ctx.moveTo(x, y)
                    open = true
                    last = r[0]
                }
                ctx.stroke()
            }
        }
    }
    Repeater {
        model: ["100", "50", "0"]
        Text {
            required property int index
            required property string modelData
            y: index * (canvas.height - 4) / 2 - 2 + (index === 2 ? -6 : 0)
            text: modelData
            font: Theme.caption
            color: Theme.text3
        }
    }
    Repeater {
        model: [qsTr("24 sa önce"), qsTr("12 sa önce"), qsTr("şimdi")]
        Text {
            required property int index
            required property string modelData
            x: canvas.x + index * canvas.width / 2 - (index === 0 ? 0 : index === 1 ? width / 2 : width)
            y: canvas.height + 4
            text: modelData
            font: Theme.caption
            color: Theme.text3
        }
    }
    Row {
        anchors.bottom: parent.bottom
        x: canvas.x
        spacing: 14
        Repeater {
            model: root.series
            Row {
                required property var modelData
                spacing: 5
                Rectangle { width: 10; height: 3; radius: 1.5; color: parent.modelData.color; anchors.verticalCenter: parent.verticalCenter }
                Text { text: parent.modelData.name; font: Theme.caption; color: Theme.text2 }
            }
        }
    }
    Text {
        anchors.centerIn: canvas
        visible: !root.rows || root.rows.length === 0
        text: qsTr("Henüz kayıt yok. Kulaklık bağlıyken pil düzeyi birkaç dakikada bir kaydedilir.")
        font: Theme.footnote
        color: Theme.text2
    }
}
