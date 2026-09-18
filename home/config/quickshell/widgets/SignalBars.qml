pragma ComponentBehavior: Bound
import QtQuick
import qs

// Four ascending bars, the leftmost `level` of them lit.
Row {
    id: root
    property int level

    spacing: 2
    height: 14

    Repeater {
        model: 4

        Rectangle {
            required property int index

            y: root.height - height
            width: 3
            height: 5 + index * 3
            radius: 1
            color: index < root.level ? Theme.accent : Qt.alpha(Theme.muted, 0.4)
        }
    }
}
