pragma ComponentBehavior: Bound
import QtQuick
import qs

// One tab per network interface; the selected one is what the panel describes.
// Wraps rather than overflowing when a machine has several interfaces.
Flow {
    id: root

    spacing: 4

    Repeater {
        model: NetworkStatus.devices

        Rectangle {
            required property var modelData
            readonly property bool current: modelData === NetworkStatus.device

            implicitWidth: label.implicitWidth + 16
            implicitHeight: label.implicitHeight + 8
            radius: Theme.roundingSmall
            color: current ? Qt.alpha(Theme.accent, 0.25) : "transparent"

            Row {
                id: label
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkStatus.iconOf(modelData)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize + 2
                    color: current ? Theme.accent : Theme.muted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: current ? Theme.brightText : Theme.muted
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: NetworkStatus.selected = parent.modelData
            }
        }
    }
}
