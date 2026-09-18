import Quickshell
import Quickshell.Wayland
import QtQuick

// A dropdown window under the bar, holding one PanelCard.
PanelWindow { // qmllint disable uncreatable-type
    id: root

    property string layerNamespace
    // only a dialog with a text field needs the keyboard; otherwise the panel
    // may sit open while you type in another window
    property bool grabKeyboard: false
    property Component card

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.keyboardFocus: root.grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // below the bar, aligned with the indicators that open these panels
    anchors {
        top: true
        right: true
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
        anchors.fill: parent
        sourceComponent: root.card
    }
}
