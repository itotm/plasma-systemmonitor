/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.faces as Faces

Faces.CompactSensorFace {
    id: root

    contentItem: ColumnLayout {
        spacing: 1

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        Repeater {
            model: root.controller.highPrioritySensorIds
            SensorRow {
                Layout.fillWidth: true
                controller: root.controller
                sensorIds: [modelData]
                color: root.colorSource.map[modelData] ?? Kirigami.Theme.highlightColor
                showText: false
            }
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
