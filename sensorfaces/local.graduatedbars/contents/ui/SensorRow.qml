/*
    One row: label · graduated bar · value [· peak].
    When given several sensors it shows their average, with the peak as a marker.
    With textSensorIds the value column shows those sensors instead of the bar's,
    and with showBarValue the bar's own value gets a column of its own before them.

    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.faces as Faces

RowLayout {
    id: row

    property Faces.SensorFaceController controller
    property string label
    property var sensorIds: []
    property var textSensorIds: []
    property color color
    property bool showBar: true
    property bool showText: true
    property bool showPeakColumn: false
    // {from, to} from the face's "ranges" option, overrides the automatic range
    property var range: null

    // Column widths shared by all rows of a face; rows report what they need
    property real labelWidth: 0
    property real valueWidth: 0
    property real peakWidth: 0
    property real barValueWidth: 0
    signal widthsNeeded(real label, real value, real peak, real barValue)

    readonly property var cfg: controller.faceConfiguration
    readonly property bool merged: sensorIds.length > 1
    readonly property bool showPeak: merged && cfg.showPeak
    readonly property bool hasText: textSensorIds.length > 0

    readonly property var stats: mainSource.stats
    readonly property var textStats: textSource.stats

    readonly property bool autoRange: !range && cfg.rangeAuto && stats.maximum > stats.minimum
    readonly property real rangeFrom: range ? range.from : autoRange ? stats.minimum : cfg.rangeFrom * cfg.rangeFromMultiplier
    readonly property real rangeTo: range ? range.to : autoRange ? stats.maximum : cfg.rangeTo * cfg.rangeToMultiplier

    function toFraction(v) {
        return rangeTo > rangeFrom ? Math.max(0, Math.min(1, (v - rangeFrom) / (rangeTo - rangeFrom))) : 0;
    }

    spacing: Kirigami.Units.smallSpacing * 2

    SensorStats {
        id: mainSource
        sensorIds: row.sensorIds
        updateRateLimit: row.controller.updateRateLimit
    }

    SensorStats {
        id: textSource
        sensorIds: row.textSensorIds
        updateRateLimit: row.controller.updateRateLimit
    }

    QQC2.Label {
        visible: row.showText && row.cfg.showLabels
        Layout.preferredWidth: row.labelWidth
        text: row.label || row.stats.name
        elide: Text.ElideRight
        onImplicitWidthChanged: row.widthsNeeded(implicitWidth, 0, 0, 0)
    }

    GraduatedBar {
        visible: row.showBar
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        fraction: row.toFraction(row.stats.value)
        peakFraction: row.showPeak ? row.toFraction(row.stats.peak) : -1
        segments: row.cfg.segments
        useGradient: row.cfg.useGradient
        color: row.color
    }

    Item {
        visible: !row.showBar
        Layout.fillWidth: true
    }

    QQC2.Label {
        visible: row.showText && row.cfg.showBarValue && row.hasText
        Layout.preferredWidth: row.barValueWidth
        horizontalAlignment: Text.AlignRight
        font.features: { "tnum": 1 }
        opacity: 0.7
        onImplicitWidthChanged: row.widthsNeeded(0, 0, 0, implicitWidth)
        text: row.stats.text
    }

    QQC2.Label {
        visible: row.showText
        Layout.preferredWidth: row.valueWidth
        horizontalAlignment: Text.AlignRight
        font.features: { "tnum": 1 }
        onImplicitWidthChanged: row.widthsNeeded(0, implicitWidth, 0, 0)
        text: row.hasText ? row.textStats.text : row.stats.text
    }

    QQC2.Label {
        visible: row.showText && row.showPeakColumn
        Layout.preferredWidth: row.peakWidth
        horizontalAlignment: Text.AlignRight
        font.features: { "tnum": 1 }
        opacity: 0.6
        onImplicitWidthChanged: row.widthsNeeded(0, 0, implicitWidth, 0)
        // Empty until the metadata arrives, or the raw peak would widen the column
        text: row.showPeak && row.stats.peakText ? "▲ " + row.stats.peakText : ""
    }
}
