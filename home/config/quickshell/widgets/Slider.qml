import QtQuick
import qs

// A 0-1 horizontal bar. Does not change `value` itself; the owner acts on
// `moved` and feeds the new value back.
Item {
    id: root

    property real value
    readonly property real clamped: Math.max(0, Math.min(1, value))

    signal moved(v: real)

    implicitWidth: 120
    implicitHeight: 16

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 6
        radius: height / 2
        color: Theme.highlight

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.clamped * parent.width
            radius: parent.radius
            color: root.enabled ? Theme.accent : Theme.muted
        }
    }

    Rectangle {
        x: root.clamped * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: 6
        color: Theme.brightText
        opacity: mouse.containsMouse || mouse.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationIn
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => root.moved(Math.max(0, Math.min(1, mouse.x / width)))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
