import QtQuick
import Pinna

// Battery lines. The range picks 1 to 24 hours from the data so little data is not squeezed to the right edge.
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
        { i: 1, name: Store.oneBattery ? qsTr("Battery") : qsTr("Left"), color: Theme.accent },
        { i: 2, name: qsTr("Right"), color: Theme.green },
        { i: 3, name: qsTr("Case"), color: Theme.orange }
    ].filter(x => !Store.oneBattery || x.i === 1)
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
            // split each series into runs; gaps longer than 20 minutes break the line
            const runs = root.series.map(s => {
                const out = []
                let cur = null, last = 0
                for (const r of rows) {
                    const v = r[s.i]
                    if (v < 0 || (cur && r[0] - last > 1200)) { cur = null; if (v < 0) continue }
                    if (r[0] < from) continue
                    if (!cur) { cur = []; out.push(cur) }
                    cur.push([(r[0] - from) / root.span * w, h - v / 100 * (h - 4)])
                    last = r[0]
                }
                return out
            })
            // soft fill under every run first, so no line is hidden under another fill
            root.series.forEach((s, k) => {
                for (const run of runs[k]) {
                    if (run.length < 2) continue
                    const g = ctx.createLinearGradient(0, 0, 0, h)
                    g.addColorStop(0, Qt.alpha(s.color, Theme.dark ? 0.22 : 0.16))
                    g.addColorStop(1, Qt.alpha(s.color, 0))
                    ctx.fillStyle = g
                    ctx.beginPath()
                    ctx.moveTo(run[0][0], h)
                    for (const p of run) ctx.lineTo(p[0], p[1])
                    ctx.lineTo(run[run.length - 1][0], h)
                    ctx.closePath()
                    ctx.fill()
                }
            })
            root.series.forEach((s, k) => {
                ctx.strokeStyle = s.color
                ctx.fillStyle = s.color
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                for (const run of runs[k]) {
                    ctx.beginPath()
                    if (run.length === 1) {
                        ctx.arc(run[0][0], run[0][1], 2, 0, 2 * Math.PI)
                        ctx.fill()
                        continue
                    }
                    run.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]))
                    ctx.stroke()
                }
            })
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: m => root.hoverX = m.x
            onExited: root.hoverX = -1
        }
        // the record under the cursor
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
        Repeater {
            model: root.series
            Rectangle {
                required property var modelData
                readonly property var v: canvas.picked ? canvas.picked[modelData.i] : -1
                visible: v >= 0
                width: 9
                height: 9
                radius: 4.5
                color: modelData.color
                border.width: 2
                border.color: Theme.card
                x: (canvas.picked ? (canvas.picked[0] - Date.now() / 1000 + root.span) / root.span * canvas.width : 0) - width / 2
                y: canvas.height - v / 100 * (canvas.height - 4) - height / 2
            }
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
        model: [qsTr("%1 h ago").arg(root.span / 3600), root.span < 14400 ? qsTr("%1 min ago").arg(root.span / 120) : qsTr("%1 h ago").arg(root.span / 7200), qsTr("now")]
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
        text: qsTr("No data yet. Battery levels are recorded every few minutes while connected.")
        font: Theme.footnote
        color: Theme.text2
    }
}
