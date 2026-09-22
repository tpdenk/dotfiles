pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import qs.audio
import qs.bluetooth
import qs.docker
import qs.network
import qs.power
import qs.screenrecord
import qs.screenshare
import qs.updates
import qs.widgets

// The top strip: no surface of its own, only the pills floating on it.
Scope {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Variants {
        model: Quickshell.screens

        PanelWindow { // qmllint disable uncreatable-type
            id: panel
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "bar"

            anchors {
                top: true
                left: true
                right: true
            }

            // the pills plus the gap that keeps them off the screen edge
            implicitHeight: 34
            color: "transparent"

            Workspaces {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 8
                }
                monitor: Hyprland.monitorFor(panel.screen)
            }

            Pill {
                id: clockPill
                anchors.centerIn: parent
                label: Qt.formatDateTime(clock.date, "yyyy-MM-dd dddd HH:mm:ss")
                labelColor: Theme.brightText
            }

            UpdatesIndicator {
                anchors {
                    right: clockPill.left
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
            }

            // trail the clock instead of joining the row of dropdowns: they
            // come and go, and must not shuffle the indicators around
            Row {
                anchors {
                    left: clockPill.right
                    leftMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                ScreenShareIndicator {}

                ScreenRecordIndicator {}
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 8
                }
                spacing: 6

                DockerIndicator {}

                AudioIndicator {}

                BluetoothIndicator {}

                NetworkIndicator {}

                PowerIndicator {}
            }
        }
    }
}
