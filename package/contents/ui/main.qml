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
    readonly property int maxLen: Math.max(2, Math.round(historyMin * 60 / intervalSec))
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property string command: {
        const url = Qt.resolvedUrl("../code/read.sh").toString();
        return "sh '" + decodeURIComponent(url.replace(/^file:\/\//, "")) + "'";
    }

    property var prevReading: null
    property bool cpuNoPerm: false
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
        cpuW = Logic.cpuWatts(prevReading, r);
        prevReading = r;
        cpuNoPerm = r.cpuNoPerm;
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
        Layout.preferredWidth: root.vertical ? -1 : lines.implicitWidth
        Layout.minimumWidth: root.vertical ? -1 : lines.implicitWidth
        Layout.preferredHeight: root.vertical ? lines.implicitHeight : -1
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        ColumnLayout {
            id: lines
            anchors.centerIn: parent
            width: root.vertical ? parent.width : implicitWidth
            spacing: 0

            Repeater {
                model: root.vertical ? Logic.panelLines(root.current) : [Logic.panelText(root.current)]
                PlasmaComponents.Label {
                    Layout.fillWidth: root.vertical
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    fontSizeMode: root.vertical ? Text.HorizontalFit : Text.FixedSize
                    minimumPixelSize: Kirigami.Theme.smallFont.pixelSize
                }
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

    fullRepresentation: ColumnLayout {
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
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.cpuNoPerm
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: "CPU-Watt: kein Leserecht – einmalig <code>sudo ./install-permissions.sh</code> ausführen"
            textFormat: Text.StyledText
        }
    }
}
