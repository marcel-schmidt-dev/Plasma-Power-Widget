import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../code/logic.js" as Logic

PlasmoidItem {
    id: root

    readonly property int intervalSec: Plasmoid.configuration.intervalSec
    readonly property int historyMin: Plasmoid.configuration.historyMin
    readonly property int fontScale: Plasmoid.configuration.fontScale
    readonly property int maxLen: Math.max(2, Math.round(historyMin * 60 / intervalSec))
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property string command: {
        const url = Qt.resolvedUrl("../code/read.sh").toString();
        return Logic.buildCommand(decodeURIComponent(url.replace(/^file:\/\//, "")));
    }

    property var prevReading: null
    property var hintList: []
    property var cpuW: null
    property var cpuC: null
    property var gpuW: null
    property var gpuC: null
    property var cpuWHist: []
    property var cpuCHist: []
    property var gpuWHist: []
    property var gpuCHist: []

    readonly property var current: ({ cpuW: cpuW, cpuC: cpuC, gpuW: gpuW, gpuC: gpuC })

    function handle(text) {
        const r = Logic.parseReading(text);
        cpuW = Logic.cpuWatts(prevReading, r, Logic.maxDtFor(intervalSec));
        prevReading = r;
        hintList = Logic.hints(r);
        cpuC = Logic.toCelsius(r.cpuTempMc);
        gpuW = Logic.toWatts(r.gpuPowerUw);
        gpuC = Logic.toCelsius(r.gpuTempMc);
        cpuWHist = Logic.pushSample(cpuWHist, cpuW, maxLen);
        cpuCHist = Logic.pushSample(cpuCHist, cpuC, maxLen);
        gpuWHist = Logic.pushSample(gpuWHist, gpuW, maxLen);
        gpuCHist = Logic.pushSample(gpuCHist, gpuC, maxLen);
    }

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            root.handle(data["stdout"]);
        }
    }

    Timer {
        interval: root.intervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        // Läuft das Skript noch vom letzten Takt, diesen Takt auslassen.
        onTriggered: {
            if (exec.connectedSources.indexOf(root.command) < 0) {
                exec.connectSource(root.command);
            }
        }
    }

    toolTipMainText: "Power Widget"
    toolTipSubText: Logic.panelText(current)

    compactRepresentation: MouseArea {
        id: compact

        // Feste Breite nach dem breitesten Fall, damit das Panel nicht bei jeder
        // Ziffernänderung springt.
        readonly property real stableWidth: Math.max(widest.advanceWidth, single.implicitWidth)
            + Kirigami.Units.smallSpacing * 2

        Layout.preferredWidth: root.vertical ? -1 : stableWidth
        Layout.minimumWidth: root.vertical ? -1 : stableWidth
        Layout.preferredHeight: root.vertical ? lines.implicitHeight : -1
        hoverEnabled: true

        // Muster aus Plasmas DefaultCompactRepresentation: Ein Klick bei offenem
        // Popup soll es schließen und nicht sofort wieder öffnen.
        property bool wasExpanded: false
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        TextMetrics {
            id: widest
            font: single.font
            text: Logic.panelText({ cpuW: 888, cpuC: 88, gpuW: 888, gpuC: 88 })
        }

        PlasmaComponents.Label {
            id: single
            visible: !root.vertical
            anchors.centerIn: parent
            font.pixelSize: Logic.panelPixelSize(Kirigami.Theme.defaultFont.pixelSize, root.fontScale, compact.height)
            text: Logic.panelText(root.current)
        }

        ColumnLayout {
            id: lines
            visible: root.vertical
            anchors.centerIn: parent
            width: parent.width
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Logic.panelLines(root.current)[0]
                font.pixelSize: Logic.panelPixelSize(Kirigami.Theme.defaultFont.pixelSize, root.fontScale, 0)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Logic.panelLines(root.current)[1]
                font.pixelSize: Logic.panelPixelSize(Kirigami.Theme.defaultFont.pixelSize, root.fontScale, 0)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    component Block: ColumnLayout {
        property string emoji
        property string label
        property var watts
        property var temp
        property var wattHist: []
        property var tempHist: []

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 4
            text: emoji + " " + label + "  " + Logic.EMOJI.power + Logic.formatWatts(watts)
                  + " · " + Logic.EMOJI.temp + Logic.formatTempLong(temp)
        }
        RowLayout {
            PlasmaComponents.Label { text: "W"; opacity: 0.7; Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5 }
            Graph { Layout.fillWidth: true; values: wattHist; lineColor: Kirigami.Theme.highlightColor; unit: "W" }
            PlasmaComponents.Label {
                text: "Spitze " + Logic.formatWatts(Logic.peak(wattHist))
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }
        }
        RowLayout {
            PlasmaComponents.Label { text: "°C"; opacity: 0.7; Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5 }
            Graph { Layout.fillWidth: true; values: tempHist; lineColor: Kirigami.Theme.negativeTextColor; unit: "°C" }
        }
    }

    fullRepresentation: Item {
        // Abstand zwischen Popup-Box und Inhalt; das Popup wächst um 2 × pad.
        readonly property real pad: Kirigami.Units.largeSpacing
        Layout.preferredWidth: content.Layout.preferredWidth + 2 * pad
        Layout.minimumWidth: content.Layout.minimumWidth + 2 * pad
        Layout.preferredHeight: content.implicitHeight + 2 * pad
        Layout.minimumHeight: content.implicitHeight + 2 * pad

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: parent.pad
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            spacing: Kirigami.Units.largeSpacing

            Block {
                emoji: Logic.EMOJI.cpu
                label: "CPU"
                watts: root.cpuW
                temp: root.cpuC
                wattHist: root.cpuWHist
                tempHist: root.cpuCHist
            }
            Block {
                emoji: Logic.EMOJI.gpu
                label: "GPU"
                watts: root.gpuW
                temp: root.gpuC
                wattHist: root.gpuWHist
                tempHist: root.gpuCHist
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "letzte " + root.historyMin + " Min."
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }
            Repeater {
                model: root.hintList
                PlasmaComponents.Label {
                    required property string modelData
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Kirigami.Theme.neutralTextColor
                    text: modelData
                }
            }
        }
    }
}
