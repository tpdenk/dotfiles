import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// A dropdown window under the bar, holding one PanelCard. `name` is its key
// in Panels: `Panels.toggle(name)`, and `qs ipc call panels toggle <name>`,
// show and hide it.
PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property string name
    property Component card
    // only a dialog with a text field needs the keyboard; otherwise the panel
    // may sit open while you type in another window
    property bool grabKeyboard: false
    property bool centered: false

    readonly property bool wanted: Panels.open === root.name
    property bool shown: false

    onWantedChanged: {
        if (wanted) {
            shown = true;
            outAnim.stop();
            inAnim.restart();
        } else if (shown) {
            inAnim.stop();
            outAnim.restart();
        }
    }

    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.name
    WlrLayershell.keyboardFocus: root.grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // below the bar, aligned with the indicators that open these panels; a
    // layer surface left unanchored on an axis is centred on it
    anchors {
        top: true
        right: !root.centered
    }
    margins {
        top: 38
        right: 8
    }

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight
    color: "transparent"

    Loader {
        id: loader
        width: parent.width
        sourceComponent: root.card
        opacity: 0
        y: 0
    }

    ParallelAnimation {
        id: inAnim
        NumberAnimation {
            target: loader
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durationIn
        }
        NumberAnimation {
            target: loader
            property: "y"
            from: -4
            to: 0
            duration: Theme.durationIn
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: outAnim
        NumberAnimation {
            target: loader
            property: "opacity"
            to: 0
            duration: Theme.durationOut
        }
        ScriptAction {
            script: root.shown = false
        }
    }
}
