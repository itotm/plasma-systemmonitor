/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.faces as Faces

Faces.SensorFace {
    id: root

    // Sensors sharing the same label are merged into one row (average + peak)
    function makeRows(ids) {
        const labels = controller.sensorLabels;
        const merge = controller.faceConfiguration.groupByLabel;
        const rows = [];
        const byLabel = {};
        for (const id of ids) {
            const label = labels[id] || "";
            if (merge && label !== "" && byLabel[label] !== undefined) {
                rows[byLabel[label]].ids.push(id);
            } else {
                if (label !== "") {
                    byLabel[label] = rows.length;
                }
                rows.push({ label: label, ids: [id] });
            }
        }
        return rows;
    }

    readonly property var rows: makeRows(controller.highPrioritySensorIds)
    readonly property var lowRows: makeRows(controller.lowPrioritySensorIds)
    readonly property bool anyMerged: rows.some(r => r.ids.length > 1) && controller.faceConfiguration.showPeak

    // With lowPriorityAsText, a low priority row sharing a bar's label becomes that bar's value
    readonly property bool lowAsText: controller.faceConfiguration.lowPriorityAsText
    readonly property var textIds: {
        const byLabel = {};
        if (lowAsText) {
            for (const r of lowRows) {
                if (r.label !== "" && rows.some(h => h.label === r.label)) {
                    byLabel[r.label] = r.ids;
                }
            }
        }
        return byLabel;
    }
    readonly property var extraRows: lowRows.filter(r => textIds[r.label] === undefined)
    readonly property bool tiles: controller.faceConfiguration.extraAsTiles
    readonly property bool tilesOnly: tiles && rows.length === 0

    // "ranges" option: "sensor/id=from:to; other/id=from:to"
    readonly property var ranges: {
        const byId = {};
        for (const entry of (controller.faceConfiguration.ranges || "").split(";")) {
            const m = entry.trim().match(/^(.+?)\s*=\s*(-?[\d.]+)\s*:\s*(-?[\d.]+)$/);
            if (m) {
                byId[m[1]] = { from: Number(m[2]), to: Number(m[3]) };
            }
        }
        return byId;
    }
    function rangeFor(ids) {
        for (const id of ids) {
            if (ranges[id] !== undefined) {
                return ranges[id];
            }
        }
        return null;
    }

    // Columns only ever grow, so the bars don't jitter as values change
    property real labelWidth: 0
    property real valueWidth: Kirigami.Units.gridUnit * 3
    property real peakWidth: Kirigami.Units.gridUnit * 3
    property real barValueWidth: Kirigami.Units.gridUnit * 2
    function fitWidths(label, value, peak, barValue) {
        labelWidth = Math.max(labelWidth, Math.ceil(label));
        valueWidth = Math.max(valueWidth, Math.ceil(value));
        peakWidth = Math.max(peakWidth, Math.ceil(peak));
        barValueWidth = Math.max(barValueWidth, Math.ceil(barValue));
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24

    contentItem: ColumnLayout {
        // Rows must never overlap: the page grows the row to fit them
        Layout.minimumHeight: implicitHeight
        spacing: Math.round(Kirigami.Units.smallSpacing / 2)

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.controller.title
            visible: root.controller.showTitle && text.length > 0
            level: 2
        }

        // With tiles only, centre them vertically: spacers above and below them, none at the bottom
        Item { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.tilesOnly }

        GridLayout {
            Layout.fillWidth: true
            visible: root.tiles && root.extraRows.length > 0
            columns: Math.max(1, Math.min(root.controller.faceConfiguration.tileColumns, root.extraRows.length))
            columnSpacing: Kirigami.Units.smallSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing * 2

            Repeater {
                model: root.tiles ? root.extraRows : []
                SensorTile {
                    // Same preferred width everywhere: the columns share the space evenly
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    controller: root.controller
                    label: modelData.label
                    sensorIds: modelData.ids
                    range: root.rangeFor(modelData.ids)
                    accentColor: root.controller.sensorColors[modelData.ids[0]] ?? Kirigami.Theme.highlightColor
                }
            }
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        Repeater {
            model: root.rows
            SensorRow {
                Layout.fillWidth: true
                controller: root.controller
                label: modelData.label
                sensorIds: modelData.ids
                textSensorIds: root.textIds[modelData.label] ?? []
                range: root.rangeFor(modelData.ids)
                color: root.colorSource.map[modelData.ids[0]] ?? Kirigami.Theme.highlightColor
                showPeakColumn: root.anyMerged
                labelWidth: root.labelWidth
                valueWidth: root.valueWidth
                peakWidth: root.peakWidth
                barValueWidth: root.barValueWidth
                onWidthsNeeded: (l, v, p, b) => root.fitWidths(l, v, p, b)
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: !root.tiles && root.extraRows.length > 0
        }

        Repeater {
            model: root.tiles ? [] : root.extraRows
            SensorRow {
                Layout.fillWidth: true
                controller: root.controller
                label: modelData.label
                sensorIds: modelData.ids
                showBar: false
                showPeakColumn: root.anyMerged
                labelWidth: root.labelWidth
                valueWidth: root.valueWidth
                peakWidth: root.peakWidth
                barValueWidth: root.barValueWidth
                onWidthsNeeded: (l, v, p, b) => root.fitWidths(l, v, p, b)
            }
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true; visible: !root.tilesOnly }
    }
}
