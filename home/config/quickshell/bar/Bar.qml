pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import qs.audio
import qs.bluetooth
import qs.network
import qs.power
import qs.screenrecord
import qs.updates
import qs.widgets

// The top strip: no surface of its own, only the pills floating on it.
Scope {
    id: root
    property string time

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
                id: clock
                anchors.centerIn: parent
                label: root.time
                labelColor: Theme.brightText
            }

            UpdatesIndicator {
                anchors {
                    right: clock.left
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
            }

            // trails the clock instead of joining the row of dropdowns: it
            // comes and goes, and must not shuffle the indicators around
            ScreenRecordIndicator {
                anchors {
                    left: clock.right
                    leftMargin: 6
                    verticalCenter: parent.verticalCenter
                }
            }

            // the dropdown indicators share the top-right corner
            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 8
                }
                spacing: 6

                AudioIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                }

                BluetoothIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                }

                NetworkIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                }

                PowerIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Process {
        id: dateProc
        command: ["date", "+%F %A %H:%M:%S"]
        running: true

        stdout: StdioCollector {
            // `date` ends its line: kept, the label would be two lines tall
            // and the text would sit above the pill's centre
            onStreamFinished: root.time = this.text.trim()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: dateProc.running = true
    }
}
