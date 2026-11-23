import QtQuick
import Pinna

// Pil çizgileri. Aralık veriye göre 1 ile 24 saat arasında seçilir, az veri sağ uca sıkışmasın.
Item {
    id: root
    property var rows: Backend.history
    readonly property int span: {
        const r = rows || []
        const age = r.length ? Date.now() / 1000 - r[0][0] : 0
        for (const h of [1, 3, 6, 12])
            if (age <= h * 3600 * 0.95) return h * 3600
        return 86400
    }
    property real hoverX: -1
    readonly property var series: [
        { i: 1, name: qsTr("Sol"), color: Theme.accent },
        { i: 2, name: qsTr("Sağ"), color: Theme.green },
        { i: 3, name: qsTr("Kutu"), color: Theme.orange }
    ]
    implicitHeight: 170
    onRowsChanged: canvas.requestPaint()
    onSpanChanged: canvas.requestPaint()
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
            const now = Date.now() / 1000, from = now - root.span
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
                let open = false, last = 0, lone = null
                const dot = () => { if (lone) { ctx.moveTo(lone[0] + 1.5, lone[1]); ctx.arc(lone[0], lone[1], 1.5, 0, 2 * Math.PI) } }
                for (const r of rows) {
                    const v = r[s.i]
                    // 20 dakikadan uzun boşlukta çizgi koparılır
                    if (v < 0 || (open && r[0] - last > 1200)) { dot(); lone = null; open = false; if (v < 0) continue }
                    if (r[0] < from) continue
                    const x = (r[0] - from) / root.span * w
                    const y = h - v / 100 * (h - 4)
                    if (open) { ctx.lineTo(x, y); lone = null } else { ctx.moveTo(x, y); lone = [x, y] }
                    open = true
                    last = r[0]
                }
                dot()
                ctx.stroke()
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: m => root.hoverX = m.x
            onExited: root.hoverX = -1
        }
        // imlecin altındaki kayıt
        readonly property var picked: {
            if (root.hoverX < 0 || !root.rows || !root.rows.length) return null
            const t = Date.now() / 1000 - root.span + root.hoverX / width * root.span
            let best = null
            for (const r of root.rows)
                if (!best || Math.abs(r[0] - t) < Math.abs(best[0] - t)) best = r
            return best && Math.abs(best[0] - t) < root.span / 30 ? best : null
        }
        Rectangle {
            visible: !!canvas.picked
            x: canvas.picked ? (canvas.picked[0] - Date.now() / 1000 + root.span) / root.span * canvas.width : 0
            width: 1
            height: canvas.height
            color: Theme.text3
        }
        Rectangle {
            visible: !!canvas.picked
            readonly property real px: canvas.picked ? (canvas.picked[0] - Date.now() / 1000 + root.span) / root.span * canvas.width : 0
            x: Math.max(0, Math.min(canvas.width - width, px - width / 2))
            y: 2
            width: tip.implicitWidth + 16
            height: tip.implicitHeight + 8
            radius: Theme.small
            color: Theme.card
            border.color: Theme.border
            Text {
                id: tip
                anchors.centerIn: parent
                font: Theme.caption
                color: Theme.text
                text: !canvas.picked ? "" : [Store.ago(canvas.picked[0])]
                    .concat(root.series.filter(s => canvas.picked[s.i] >= 0).map(s => s.name + " " + canvas.picked[s.i] + "%")).join("   ")
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
        model: [qsTr("%1 sa önce").arg(root.span / 3600), root.span < 14400 ? qsTr("%1 dk önce").arg(root.span / 120) : qsTr("%1 sa önce").arg(root.span / 7200), qsTr("şimdi")]
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
