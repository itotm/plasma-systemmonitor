/*
    Segmented bar: each segment lights up in proportion to the value,
    coloured by its position on a green → amber → red scale.

    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: bar

    property real fraction: 0
    property real peakFraction: -1
    property int segments: 20
    property bool useGradient: true
    property color color: Kirigami.Theme.highlightColor

    readonly property real gap: 2
    readonly property real minimumSegmentWidth: 5
    // Fewer, wider segments when the bar is narrow
    readonly property int count: Math.max(4, Math.min(segments, Math.floor((width + gap) / (minimumSegmentWidth + gap))))
    readonly property color trackColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)

    implicitWidth: Kirigami.Units.gridUnit * 8
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.6)

    // Hue mix along the shorter arc. Kirigami.ColorUtils.linearInterpolation does not wrap, so from
    // orange to a red just below 360° it took the long way (yellow, green, cyan, blue); a plain RGB
    // mix avoids that but turns green → orange into olive
    function mix(a, b, t) {
        let d = b.hsvHue - a.hsvHue;
        if (d > 0.5) {
            d -= 1;
        } else if (d < -0.5) {
            d += 1;
        }
        return Qt.hsva((a.hsvHue + d * t + 1) % 1,
                       a.hsvSaturation + (b.hsvSaturation - a.hsvSaturation) * t,
                       a.hsvValue + (b.hsvValue - a.hsvValue) * t, 1);
    }

    function colorAt(t) {
        if (!useGradient) {
            return color;
        }
        if (t < 0.5) {
            return mix(Kirigami.Theme.positiveTextColor, Kirigami.Theme.neutralTextColor, t * 2);
        }
        return mix(Kirigami.Theme.neutralTextColor, Kirigami.Theme.negativeTextColor, (t - 0.5) * 2);
    }

    Row {
        anchors.fill: parent
        spacing: bar.gap

        Repeater {
            model: bar.count

            Rectangle {
                readonly property real fill: Math.max(0, Math.min(1, bar.fraction * bar.count - index))

                width: (bar.width - bar.gap * (bar.count - 1)) / bar.count
                height: bar.height
                radius: 1
                color: bar.trackColor

                Rectangle {
                    width: parent.width * parent.fill
                    height: parent.height
                    radius: parent.radius
                    color: bar.colorAt((index + 0.5) / bar.count)
                }
            }
        }
    }

    // Peak marker, used when several sensors are merged into one row
    Rectangle {
        visible: bar.peakFraction >= 0
        x: Math.round(Math.max(0, Math.min(1, bar.peakFraction)) * (bar.width - width))
        y: -2
        width: 2
        height: bar.height + 4
        radius: 1
        color: Kirigami.Theme.textColor
    }
}
