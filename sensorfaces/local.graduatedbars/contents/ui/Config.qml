/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.faces as Faces

Kirigami.FormLayout {
    property alias cfg_rangeAuto: rangeAutoCheckbox.checked
    property alias cfg_rangeFrom: rangeFromSpin.value
    property alias cfg_rangeFromUnit: rangeFromSpin.unit
    property alias cfg_rangeFromMultiplier: rangeFromSpin.multiplier
    property alias cfg_rangeTo: rangeToSpin.value
    property alias cfg_rangeToUnit: rangeToSpin.unit
    property alias cfg_rangeToMultiplier: rangeToSpin.multiplier
    property alias cfg_segments: segmentsSpin.value
    property alias cfg_useGradient: gradientCheckbox.checked
    property alias cfg_groupByLabel: groupCheckbox.checked
    property alias cfg_showLabels: labelsCheckbox.checked
    property alias cfg_showPeak: peakCheckbox.checked
    property alias cfg_lowPriorityAsText: lowAsTextCheckbox.checked
    property alias cfg_showBarValue: barValueCheckbox.checked
    property alias cfg_extraAsTiles: tilesCheckbox.checked
    property alias cfg_tileColumns: tileColumnsSpin.value
    property alias cfg_ranges: rangesField.text

    QQC2.SpinBox {
        id: segmentsSpin
        Kirigami.FormData.label: "Segments:"
        from: 4
        to: 50
    }
    QQC2.CheckBox {
        id: gradientCheckbox
        text: "Green → red scale (otherwise sensor colour)"
    }
    QQC2.CheckBox {
        id: groupCheckbox
        text: "Merge sensors with the same label (average + peak)"
    }
    QQC2.CheckBox {
        id: labelsCheckbox
        text: "Show labels"
    }
    QQC2.CheckBox {
        id: peakCheckbox
        text: "Show the peak of merged sensors"
    }
    QQC2.CheckBox {
        id: lowAsTextCheckbox
        text: "Show low priority sensors as the value of the row with the same label"
    }
    QQC2.CheckBox {
        id: barValueCheckbox
        enabled: lowAsTextCheckbox.checked
        text: "Also show the bar's own value before that text"
    }
    QQC2.CheckBox {
        id: tilesCheckbox
        text: "Show the other low priority sensors as tiles above the bars"
    }
    QQC2.SpinBox {
        id: tileColumnsSpin
        Kirigami.FormData.label: "Tiles per row:"
        enabled: tilesCheckbox.checked
        from: 1
        to: 8
    }
    QQC2.TextField {
        id: rangesField
        Kirigami.FormData.label: "Ranges per sensor:"
        Layout.fillWidth: true
        placeholderText: "sensor/id=0:100; other/id=30:95"
    }
    QQC2.CheckBox {
        id: rangeAutoCheckbox
        Kirigami.FormData.label: "Range:"
        text: "Automatic (falls back to the values below)"
    }
    Faces.SensorRangeSpinBox {
        id: rangeFromSpin
        Kirigami.FormData.label: "From:"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        sensors: controller.highPrioritySensorIds
    }
    Faces.SensorRangeSpinBox {
        id: rangeToSpin
        Kirigami.FormData.label: "To:"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        sensors: controller.highPrioritySensorIds
    }
}
