pragma ComponentBehavior: Bound
import QtQuick
import qs

// A row of mutually exclusive options. Does not change `current` itself; the
// owner acts on `selected` and feeds the new index back. `enabled: false`
// greys the control and swallows the clicks.
Rectangle {
    id: root

    property var options: []
    property int current: -1

    signal selected(index: int)

    readonly property int inset: 2

    implicitWidth: row.implicitWidth + 2 * inset
    implicitHeight: row.implicitHeight + 2 * inset
    radius: Theme.roundingSmall
    color: Qt.alpha(Theme.muted, 0.25)
    border.width: Theme.borderSize
    border.color: root.enabled ? Theme.accent : Theme.muted

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.inset

        Repeater {
            model: root.options

            Rectangle {
                id: segment
                required property string modelData
                required property int index

                readonly property bool active: root.current === segment.index

                implicitWidth: label.implicitWidth + 14
                implicitHeight: label.implicitHeight + 4
                radius: Theme.roundingSmall
                color: segment.active ? Theme.accent : hover.containsMouse ? Qt.alpha(Theme.accent, 0.2) : "transparent"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: segment.modelData
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    color: segment.active ? Theme.background : root.enabled ? Theme.text : Theme.muted
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selected(segment.index)
                }
            }
        }
    }
}
