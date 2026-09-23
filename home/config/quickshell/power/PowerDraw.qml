pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

// What each device is drawing, biggest first, each row filled to its share of
// the biggest.
SelectList {
    title: "Draw"
    placeholder: "No readable power sensors"
    maxHeight: 8 * 22

    model: ScriptModel {
        values: PowerStatus.draws
    }

    delegate: Item {
        id: row
        required property var modelData
        readonly property bool unmeasured: modelData.kind === "unmeasured"

        width: ListView.view.width
        implicitHeight: 22

        Rectangle {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: parent.width * Math.min(1, row.modelData.watts / PowerStatus.peakWatts)
            height: parent.height - 2
            radius: Theme.roundingSmall
            color: Qt.alpha(row.unmeasured ? Theme.muted : Theme.accent, 0.16)
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: 6
                right: watts.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: row.modelData.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: row.unmeasured ? Theme.muted : Theme.text
        }

        Text {
            id: watts
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            text: `${row.modelData.watts.toFixed(1)} W`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: row.unmeasured ? Theme.muted : Theme.brightText
        }
    }
}
