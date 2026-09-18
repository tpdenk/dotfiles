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

Scope {
    id: root
    property string time

    Variants {
        model: Quickshell.screens

        PanelWindow { // qmllint disable uncreatable-type
            id: panel
            required property var modelData
            screen: modelData
            // matched by the blur layer rule in hyprland.lua
            WlrLayershell.namespace: "bar"

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 30
            // fully transparent: the compositor blur is the bar's background
            color: "transparent"

            // content area: everything above the accent strip
            Item {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: accent.top
                }

                Workspaces {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8
                    }
                    monitor: Hyprland.monitorFor(panel.screen)
                }

                Text {
                    anchors.centerIn: parent
                    text: root.time
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                }

                // the dropdown indicators share the top-right corner
                Row {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 8
                    }
                    spacing: 10

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

            // the focused window border gradient
            Rectangle {
                id: accent
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Theme.borderSize
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.accentSecondary }
                }
            }
        }
    }

    Process {
        id: dateProc
        command: ["date", "+%F %A %H:%M:%S"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.time = this.text
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: dateProc.running = true
    }
}
