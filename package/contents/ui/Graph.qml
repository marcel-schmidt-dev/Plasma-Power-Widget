import QtQuick
import org.kde.kirigami as Kirigami

// Kleine Verlaufslinie. values: Array aus Zahlen oder null (null = Lücke).
// Skala von 0 bis zum größten Wert im Puffer.
Canvas {
    id: graph

    property var values: []
    property color lineColor: Kirigami.Theme.highlightColor
    property string unit: ""

    implicitHeight: Kirigami.Units.gridUnit * 2
    implicitWidth: Kirigami.Units.gridUnit * 10

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.15);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, height - 0.5);
        ctx.lineTo(width, height - 0.5);
        ctx.stroke();

        const vals = values || [];
        if (vals.length < 2) return;

        let max = 0;
        for (const v of vals) if (v !== null && v > max) max = v;
        if (max <= 0) max = 1;

        const step = width / (vals.length - 1);
        const pad = 1.5;
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        ctx.beginPath();
        let drawing = false;
        for (let i = 0; i < vals.length; i++) {
            const v = vals[i];
            if (v === null || v === undefined) { drawing = false; continue; }
            const x = i * step;
            const y = pad + (height - 2 * pad) * (1 - v / max);
            if (drawing) ctx.lineTo(x, y); else ctx.moveTo(x, y);
            drawing = true;
        }
        ctx.stroke();
    }
}
