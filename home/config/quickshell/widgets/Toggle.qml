import QtQuick
import qs

// A sliding on/off switch. Does not change `checked` itself; the owner is
// expected to act on `toggled` and feed the new state back.
Rectangle {
    id: root
    property bool checked

    signal toggled(on: bool)

    implicitWidth: 34
    implicitHeight: 18
    radius: height / 2
    color: checked ? Qt.tint(Theme.highlight, Qt.alpha(Theme.accent, 0.45)) : Theme.highlight

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationIn
        }
    }

    Rectangle {
        id: knob
        readonly property int inset: 3

        x: root.checked ? root.width - width - inset : inset
        y: inset
        width: height
        height: root.height - 2 * inset
        radius: height / 2
        color: root.checked ? Theme.accent : root.enabled ? Theme.text : Theme.muted

        Behavior on x {
            NumberAnimation {
                duration: Theme.durationIn
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
