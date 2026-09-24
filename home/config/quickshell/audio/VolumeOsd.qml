import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.widgets

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property bool shown: false
    property bool armed: false

    function poke(): void {
        if (!root.armed || Panels.open === "audio")
            return;
        root.shown = true;
        card.opacity = 1;
        hide.restart();
    }

    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "osd"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        bottom: true
    }
    margins {
        bottom: 64
    }
    implicitWidth: 320
    implicitHeight: 40
    color: "transparent"
    mask: Region {}

    Connections {
        target: AudioStatus

        function onSinkChanged(): void {
            root.armed = false;
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: AudioStatus.sink?.audio ?? null

        function onVolumesChanged(): void {
            root.poke();
        }
        function onMutedChanged(): void {
            root.poke();
        }
    }

    Timer {
        id: hide
        interval: 1200
        onTriggered: fadeOut.restart()
    }

    SequentialAnimation {
        id: fadeOut
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: Theme.durationOut
        }
        ScriptAction {
            script: root.shown = false
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: height / 2
        color: Theme.background
        border.width: 1
        border.color: Theme.highlight

        Row {
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
            }
            spacing: 10

            Text {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                text: AudioStatus.icon
                font.family: Theme.fontFamily
                font.pointSize: Theme.h2Size
                color: AudioStatus.muted ? Theme.muted : Theme.accent
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - glyph.width - value.width - 2 * parent.spacing
                enabled: !AudioStatus.muted
                value: AudioStatus.volume
            }

            Text {
                id: value
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: AudioStatus.muted ? "muted" : AudioStatus.percent(AudioStatus.sink)
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                color: AudioStatus.muted ? Theme.muted : Theme.brightText
            }
        }
    }
}
