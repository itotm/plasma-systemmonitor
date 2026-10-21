/*
    Stat tile: big value, small label and, when the sensor has a range,
    a thin graduated bar under them.

    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.faces as Faces

Rectangle {
    id: tile

    property Faces.SensorFaceController controller
    property string label
    property var sensorIds: []
    property color accentColor: Kirigami.Theme.highlightColor
    // {from, to} from the face's "ranges" option; otherwise the sensor's own range, if any
    property var range: null

    readonly property var cfg: controller.faceConfiguration
    readonly property var stats: mainSource.stats
    readonly property real rangeFrom: range ? range.from : stats.minimum
    readonly property real rangeTo: range ? range.to : stats.maximum
    readonly property bool hasRange: rangeTo > rangeFrom

    implicitWidth: content.implicitWidth + padding * 2
    implicitHeight: content.implicitHeight + padding * 2

    readonly property real padding: Kirigami.Units.smallSpacing * 2

    radius: Kirigami.Units.cornerRadius
    color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)

    SensorStats {
        id: mainSource
        sensorIds: tile.sensorIds
        updateRateLimit: tile.controller.updateRateLimit
    }

    // Accent strip in the sensor colour
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            topMargin: tile.padding
            bottomMargin: tile.padding
        }
        width: 3
        radius: 1.5
        color: tile.accentColor
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: tile.padding
        anchors.leftMargin: tile.padding + 3
        spacing: 0

        QQC2.Label {
            Layout.fillWidth: true
            text: tile.stats.text
            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.3)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            elide: Text.ElideRight
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: tile.label || tile.stats.name
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
        }

        GraduatedBar {
            visible: tile.hasRange
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            implicitHeight: 4
            segments: 12
            useGradient: tile.cfg.useGradient
            color: tile.accentColor
            fraction: tile.hasRange ? Math.max(0, Math.min(1, (tile.stats.value - tile.rangeFrom) / (tile.rangeTo - tile.rangeFrom))) : 0
        }
    }
}
