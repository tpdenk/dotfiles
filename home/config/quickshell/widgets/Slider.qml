import QtQuick
import qs

// A 0-1 horizontal bar. Does not change `value` itself; the owner acts on
// `moved` and feeds the new value back.
Rectangle {
    id: root

    property real value

    signal moved(v: real)

    implicitWidth: 120
    implicitHeight: 12
    radius: height / 2
    color: Qt.alpha(Theme.muted, 0.25)
    border.width: Theme.borderSize
    border.color: Theme.accent

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: Math.max(0, Math.min(1, root.value)) * parent.width
        radius: parent.radius
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => root.moved(Math.max(0, Math.min(1, mouse.x / width)))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
    }
}
