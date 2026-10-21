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
        if (unit === Formatter.Units.UnitMegaHertz) {
            // Always GHz, so clocks don't jump between "605.0 MHz" and "3.3 GHz"
            display = Formatter.Formatter.formatValueShowNull(value, unit, Formatter.Units.MetricPrefixGiga);
        } else if (sensors.count > 1) {
            // ShowNull: an idle core reads "0.0%" instead of nothing
            display = Formatter.Formatter.formatValueShowNull(value, unit);
        }
        return {
            value: value,
            peak: count > 0 ? top : 0,
            unit: unit,
            minimum: first ? first.minimum : 0,
            maximum: first ? first.maximum : 0,
            name: first ? (first.shortName || first.name) : "",
            text: display,
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
        }
        onObjectAdded: root.recompute()
        onObjectRemoved: root.recompute()
    }
}
