pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs

Scope {
    id: root
    property string time

    Variants {
        model: Quickshell.screens

        PanelWindow { // qmllint disable uncreatable-type
            id: panel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 30
            color: HyprColors.shadow

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
                    color: HyprColors.activeBorder
                }
            }

            // first -> last stop of the focused window border gradient
            Rectangle {
                id: accent
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: HyprColors.borderSize
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: HyprColors.activeBorder }
                    GradientStop { position: 1; color: HyprColors.activeBorderEnd }
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
