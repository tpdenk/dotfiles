pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.screenrecord
import qs.widgets

// The screenshot's keybind surface; the capture itself is ScreenshotStatus.
Scope {
    id: root

    readonly property var shot: ScreenshotStatus.last
    readonly property var monitor: shot ? Hyprland.monitors.values.find(m => m.name === root.shot.output) ?? null : null
    readonly property var ipc: root.monitor?.lastIpcObject ?? null

    PanelWindow { // qmllint disable uncreatable-type
        id: win
        visible: root.shot !== null
        screen: Quickshell.screens.find(s => s.name === root.shot?.output) ?? null

        readonly property real sx: root.shot ? Number(root.shot.x) - (root.ipc?.x ?? 0) : 0
        readonly property real sy: root.shot ? Number(root.shot.y) - (root.ipc?.y ?? 0) : 0
        readonly property real sw: root.shot ? Number(root.shot.w) : 0
        readonly property real sh: root.shot ? Number(root.shot.h) : 0
        readonly property real screenW: win.screen?.width ?? 0
        readonly property real screenH: win.screen?.height ?? 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screenshot-toolbar"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
        }
        margins {
            left: Math.max(8, Math.min(win.screenW - win.implicitWidth - 8, win.sx + (win.sw - win.implicitWidth) / 2))
            top: {
                const below = win.sy + win.sh + 8;
                if (below + win.implicitHeight <= win.screenH - 8)
                    return below;
                const above = win.sy - win.implicitHeight - 8;
                if (above >= 40)
                    return above;
                return win.sy + win.sh - win.implicitHeight - 48;
            }
        }
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        color: "transparent"

        onVisibleChanged: {
            if (!visible)
                return;
            card.opacity = 0;
            card.scale = 0.96;
            appear.restart();
            countdown.restart();
        }

        ParallelAnimation {
            id: appear
            NumberAnimation {
                target: card
                property: "opacity"
                to: 1
                duration: Theme.durationIn
            }
            NumberAnimation {
                target: card
                property: "scale"
                to: 1
                duration: Theme.durationIn * 1.5
                easing.type: Easing.OutBack
            }
        }

        property real remaining: 1

        NumberAnimation {
            id: countdown
            target: win
            property: "remaining"
            from: 1
            to: 0
            duration: 8000
            paused: running && cardHover.hovered
            onFinished: ScreenshotStatus.dismiss()
        }

        component Action: Rectangle {
            id: action

            property string glyph
            property string label
            property color tint: Theme.text

            signal clicked

            width: 68
            height: 60
            radius: Theme.roundingSmall
            color: actionMouse.containsMouse ? Theme.highlight : Theme.base

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationIn
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: action.glyph
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.h2Size
                    color: action.tint
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: action.label
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    color: actionMouse.containsMouse ? Theme.brightText : Theme.text
                }
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: action.clicked()
            }
        }

        Rectangle {
            id: card
            implicitWidth: layout.implicitWidth + 24
            implicitHeight: layout.implicitHeight + 24
            radius: Theme.roundingLarge
            color: Theme.background
            border.width: 1
            border.color: Theme.highlight
            clip: true

            HoverHandler {
                id: cardHover
            }

            Row {
                id: layout
                anchors.centerIn: parent
                spacing: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 128
                    height: 80
                    radius: Theme.roundingSmall
                    color: Theme.base
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: root.shot ? "file://" + root.shot.path : ""
                        sourceSize.height: 160
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    spacing: 4

                    Row {
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(0xf012c)
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.h2Size
                            color: Theme.success
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Screenshot saved"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.h3Size
                            color: Theme.brightText
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.shot ? `${root.shot.w}×${root.shot.h} · on the clipboard` : ""
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.smallSize
                        color: Theme.text
                    }

                    Text {
                        width: parent.width
                        text: root.shot ? root.shot.path.replace(Quickshell.env("HOME"), "~") : ""
                        elide: Text.ElideMiddle
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.smallSize
                        color: Theme.muted
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Action {
                        glyph: String.fromCodePoint(0xf02e9)
                        label: "open"
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", root.shot.path]);
                            ScreenshotStatus.dismiss();
                        }
                    }

                    Action {
                        glyph: String.fromCodePoint(0xf03eb)
                        label: "edit"
                        onClicked: {
                            // satty reads strftime specifiers in the output name, so a literal % doubles
                            Quickshell.execDetached(["satty", "--filename", root.shot.path, "--output-filename", root.shot.path.replace(/%/g, "%%"), "--copy-command", "wl-copy"]);
                            ScreenshotStatus.dismiss();
                        }
                    }

                    Action {
                        glyph: String.fromCodePoint(0xf024b)
                        label: "folder"
                        onClicked: {
                            Quickshell.execDetached(["xdg-terminal-exec", "--", "lf", root.shot.path]);
                            ScreenshotStatus.dismiss();
                        }
                    }

                    Action {
                        glyph: ScreenRecordStatus.icon
                        label: "record"
                        tint: Theme.alert
                        onClicked: {
                            const s = root.shot;
                            ScreenshotStatus.dismiss();
                            ScreenRecordStatus.arm(s.kind, s.output, s.x, s.y, s.w, s.h);
                        }
                    }

                    Action {
                        glyph: String.fromCodePoint(0xf0a7a)
                        label: "discard"
                        tint: Theme.muted
                        onClicked: ScreenshotStatus.discard()
                    }
                }
            }

            Text {
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 6
                }
                text: String.fromCodePoint(0xf0156)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: closeMouse.containsMouse ? Theme.brightText : Theme.muted

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ScreenshotStatus.dismiss()
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: 1
                    bottomMargin: 1
                }
                width: (parent.width - 2) * win.remaining
                height: 2
                color: cardHover.hovered ? Theme.muted : Theme.accent
            }
        }
    }

    IpcHandler {
        target: "screenshot"

        function take(): void {
            ScreenshotStatus.take();
        }
    }
}
