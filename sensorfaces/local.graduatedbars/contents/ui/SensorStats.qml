/*
    Live average, peak and metadata (from the first sensor) of a list of sensors.

    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.formatter as Formatter

QtObject {
    id: root

    property var sensorIds: []
    property int updateRateLimit: 0

    property var stats: summarize()

    // Values computed here, not by the sensor. Clocks always in GHz, so they don't jump between
    // "605.0 MHz" and "3.3 GHz". Anything else with one decimal: the formatter drops it for whole
    // numbers coming from JS ("4%" next to "4.1%"), and with it an idle core reads "0.0%", not nothing
    function format(v, unit) {
        return unit === Formatter.Units.UnitMegaHertz
            ? Formatter.Formatter.formatValueShowNull(v, unit, Formatter.Units.MetricPrefixGiga)
            : Formatter.Formatter.formatValueWithPrecision(v, unit, 1);
    }

    function summarize() {
        let sum = 0, count = 0, top = -Infinity;
        for (let i = 0; i < sensors.count; ++i) {
            const s = sensors.objectAt(i);
            const v = s ? Number(s.value) : NaN;
            if (s && s.value !== undefined && s.value !== null && !isNaN(v)) {
                sum += v;
                count += 1;
                top = Math.max(top, v);
            }
        }
        const first = sensors.objectAt(0);
        const value = count > 0 ? sum / count : 0;
        const unit = first ? first.unit : Formatter.Units.UnitInvalid;
        let display = first ? first.formattedValue : "";
        if (first && first.status !== Sensors.Sensor.Ready) {
            // Metadata not loaded yet: without a unit the raw number ("24.500000000000004") would
            // widen the value columns, which only ever grow, and squeeze the bars for good.
            // Not a unit check: text sensors (OS name, kernel) keep UnitInvalid once loaded too
            display = "";
        } else if (unit === Formatter.Units.UnitMegaHertz || sensors.count > 1) {
            display = format(value, unit);
        }
        // Empty like the value until the metadata arrives
        const peakText = count === 0 || display === "" ? "" : format(top, unit);
        return {
            value: value,
            peak: count > 0 ? top : 0,
            unit: unit,
            minimum: first ? first.minimum : 0,
            maximum: first ? first.maximum : 0,
            name: first ? (first.shortName || first.name) : "",
            text: display,
            peakText: peakText,
            merged: sensors.count > 1
        };
    }

    function recompute() {
        stats = summarize();
    }

    readonly property Instantiator sensors: Instantiator {
        model: root.sensorIds
        delegate: Sensors.Sensor {
            sensorId: modelData
            updateRateLimit: root.updateRateLimit
            onValueChanged: root.recompute()
            onMetaDataChanged: root.recompute()
            // metaDataChanged can come before the status turns Ready, and text sensors never change value
            onStatusChanged: root.recompute()
        }
        onObjectAdded: root.recompute()
        onObjectRemoved: root.recompute()
    }
}
