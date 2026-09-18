import QtQuick
import qs

// A sliding on/off switch. Does not change `checked` itself; the owner is
// expected to act on `toggled` and feed the new state back.
Rectangle {
    id: root
    property bool checked

    signal toggled(on: bool)

    implicitWidth: 38
    implicitHeight: 20
    radius: height / 2
    color: Qt.alpha(checked ? Theme.accent : Theme.muted, 0.25)
    border.width: Theme.borderSize
    border.color: checked ? Theme.accent : Theme.muted

    Rectangle {
        id: knob
        readonly property int inset: 3

        x: root.checked ? root.width - width - inset : inset
        y: inset
        width: height
        height: root.height - 2 * inset
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.muted

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled(!root.checked)
    }
}
