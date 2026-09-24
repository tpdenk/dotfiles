pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

Scope {
    PanelWindow { // qmllint disable uncreatable-type
        id: win
        visible: Session.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "session"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                keys.forceActiveFocus();
                dim.opacity = 0;
                appear.restart();
            }
        }

        NumberAnimation {
            id: appear
            target: dim
            property: "opacity"
            to: 1
            duration: Theme.durationIn
        }

        Rectangle {
            id: dim
            anchors.fill: parent
            color: Qt.alpha(Theme.background, 0.8)

            MouseArea {
                anchors.fill: parent
                onClicked: Session.hide()
            }

            Row {
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: Session.actions

                    Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool current: Session.current === index
                        readonly property bool armed: Session.armed === modelData.id

                        width: 128
                        height: 128
                        radius: Theme.roundingLarge
                        color: tileMouse.containsMouse || current ? Theme.base : Theme.background
                        border.width: current ? Theme.borderSize : 1
                        border.color: armed ? Theme.warning : current ? Theme.accent : Theme.highlight

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String.fromCodePoint(tile.modelData.glyph)
                                font.family: Theme.fontFamily
                                font.pointSize: 28
                                color: tile.armed ? Theme.warning : tile.current ? Theme.accent : Theme.text
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.armed ? "press again" : tile.modelData.label
                                font.family: Theme.fontFamily
                                font.pointSize: tile.armed ? Theme.smallSize : Theme.fontSize
                                color: tile.armed ? Theme.warning : Theme.brightText
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `[${tile.modelData.key}]`
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.smallSize
                                color: Theme.muted
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: Session.current = tile.index
                            onClicked: Session.trigger(tile.modelData.id)
                        }
                    }
                }
            }
        }

        Item {
            id: keys
            focus: true

            Keys.onPressed: event => {
                const count = Session.actions.length;
                if (event.key === Qt.Key_Escape)
                    Session.hide();
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab)
                    Session.current = (Session.current + count - 1) % count;
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                    Session.current = (Session.current + 1) % count;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                    Session.trigger(Session.actions[Session.current].id);
                else {
                    const action = Session.actions.find(a => a.key === event.text.toLowerCase());
                    if (!action)
                        return;
                    Session.trigger(action.id);
                }
                event.accepted = true;
            }
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            if (Session.open)
                Session.hide();
            else
                Session.show("");
        }
    }
}
