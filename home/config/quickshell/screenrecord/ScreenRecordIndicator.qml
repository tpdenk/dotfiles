import QtQuick
import qs
import qs.widgets

// Bar pill, on screen from the moment a capture is asked for: a countdown on
// a background flashing bright orange, then a red record dot fading once a
// second for as long as the encoder runs. Click stops the capture, keeping
// what was recorded, or drops the countdown before it starts one.
Pill {
    id: root

    // how far into the flash the pill is; animated, so a plain property
    property real pulse: 1
    // the countdown's glyph and text, dark while the flash is at its brightest
    readonly property color countText: Qt.tint(Theme.brightText, Qt.alpha(Theme.background, root.pulse))

    visible: ScreenRecordStatus.active

    glyph: ScreenRecordStatus.icon
    label: ScreenRecordStatus.label
    // the countdown owns the whole chip; the record dot alone blinks once the
    // capture is running, as that is what has to stay legible for an hour
    color: ScreenRecordStatus.counting ? Qt.tint(Theme.base, Qt.alpha(Theme.warning, root.pulse)) : Theme.base
    glyphColor: ScreenRecordStatus.counting ? root.countText : Qt.alpha(Theme.alert, root.pulse)
    labelColor: ScreenRecordStatus.counting ? root.countText : Theme.brightText

    onClicked: ScreenRecordStatus.stop()

    // hard edged, two flashes per counted second: this is the warning that the
    // screen is about to be recorded, so it is the louder of the two
    SequentialAnimation {
        running: ScreenRecordStatus.counting
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "pulse"
            to: 0.15
            duration: 250
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "pulse"
            to: 1
            duration: 250
            easing.type: Easing.InQuad
        }
    }

    // and a slow fade in and out once a second while it records: visible at a
    // glance, but not something to sit next to for an hour
    SequentialAnimation {
        running: ScreenRecordStatus.recording
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "pulse"
            to: 0.25
            duration: 500
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "pulse"
            to: 1
            duration: 500
            easing.type: Easing.InOutSine
        }
    }
}
