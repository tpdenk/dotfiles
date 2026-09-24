pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import qs.audio
import qs.bluetooth
import qs.docker
import qs.mouse
import qs.network
import qs.notifications
import qs.power
import qs.screenrecord
import qs.screenshare
import qs.tailscale
import qs.updates
import qs.widgets

// The top strip: no surface of its own, only the pills floating on it.
Scope {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Calendar {}

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
                maxWidth: clockPill.x - 16
                monitor: Hyprland.monitorFor(panel.screen)
            }

            Pill {
                id: clockPill
                anchors.centerIn: parent
                highlight: Panels.open === "calendar"
                onClicked: Panels.toggle("calendar")

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    color: Theme.text
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    font.bold: true
                    color: Theme.brightText
                }
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 8
                }
                spacing: 6

                Capsule {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: updates.shown || share.shown || record.shown

                    UpdatesIndicator {
                        id: updates
                    }

                    ScreenShareIndicator {
                        id: share
                    }

                    ScreenRecordIndicator {
                        id: record
                    }
                }

                Capsule {
                    anchors.verticalCenter: parent.verticalCenter

                    Pill {
                        bare: true
                        glyph: String.fromCodePoint(Panels.statusExpanded ? 0xf0142 : 0xf0141)
                        glyphColor: hovered || Panels.statusExpanded ? Theme.text : Theme.muted
                        onClicked: Panels.statusExpanded = !Panels.statusExpanded
                    }

                    TailscaleIndicator {}

                    DockerIndicator {}

                    MouseIndicator {}

                    BluetoothIndicator {}

                    NetworkIndicator {}

                    AudioIndicator {}

                    PowerIndicator {}

                    NotificationIndicator {}
                }
            }
        }
    }
}
