pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs

// A drop-down picker: a capsule naming the current option, all options in a
// popup beneath it. Does not change `current` itself; the owner acts on
// `selected` and feeds the new index back. `enabled: false` greys the capsule
// and swallows the click.
Rectangle {
    id: root

    // array of strings
    property var options: []
    property int current: -1
    // shown while `current` is -1
    property string placeholder: "—"
    property alias dbgOpen: popup.visible // XXX throwaway

    signal selected(index: int)

    implicitWidth: label.implicitWidth + chevron.implicitWidth + 16
    implicitHeight: 20
    radius: Theme.roundingSmall
    color: hover.containsMouse || popup.visible ? Theme.base : Theme.highlight

    // the panel hiding, or the row going away, must take the popup with it
    readonly property bool hostVisible: root.visible && root.Window.visibility !== Window.Hidden
    onHostVisibleChanged: if (!hostVisible) popup.visible = false

    Row {
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: label
            text: root.current >= 0 && root.current < root.options.length ? root.options[root.current] : root.placeholder
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: root.enabled ? Theme.text : Theme.muted
        }

        Text {
            id: chevron
            // chevron-down
            text: String.fromCodePoint(0xf0140)
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        // hang off the capsule's bottom-right corner and grow down and to the
        // left, so a wide list stays inside the card
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 4
        // click outside dismisses and clears `visible`
        grabFocus: true
        color: "transparent"
        implicitWidth: Math.max(root.width, 140)
        implicitHeight: list.implicitHeight + 8

        Rectangle {
            anchors.fill: parent
            radius: Theme.roundingSmall
            color: Theme.base
            border.width: Theme.borderSize
            border.color: Theme.highlight

            Column {
                id: list
                anchors {
                    fill: parent
                    margins: 4
                }

                Repeater {
                    model: root.options

                    SelectRow {
                        required property string modelData
                        required property int index
                        width: list.width
                        label: modelData
                        labelColor: index === root.current ? Theme.accent : Theme.text
                        onClicked: {
                            popup.visible = false;
                            root.selected(index);
                        }
                    }
                }
            }
        }
    }
}
