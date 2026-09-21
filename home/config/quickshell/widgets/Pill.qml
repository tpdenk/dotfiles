import QtQuick
import qs

// A bar chip: an opaque rounded slab holding a glyph and a short label, tinted
// while the panel it opens is on screen. Extra children are appended to the
// same row, so an entry needing a second glyph just declares one.
Rectangle {
    id: root

    property string glyph
    property string label
    property color glyphColor: Theme.accent
    property color labelColor: Theme.text
    // elide the label past this width; 0 leaves it unbounded
    property real labelLimit: 0
    // the panel this chip opens is open
    property bool highlight: false

    default property alias content: row.data

    signal clicked

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: height / 2
    // tinted rather than alpha blended: the bar itself paints nothing, so a
    // translucent chip would show the raw wallpaper through it
    color: highlight ? Qt.tint(Theme.base, Qt.alpha(Theme.accent, 0.3)) : Theme.base

    // first child, so anything clickable inside `content` sits above it and
    // gets the press; a chip without one is clickable as a whole
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.h2Size
            color: root.glyphColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.label
            // 0 means "as wide as it needs"; a wifi SSID is the one label
            // long enough to need a cap
            width: root.labelLimit > 0 ? Math.min(implicitWidth, root.labelLimit) : implicitWidth
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: root.labelColor
        }
    }
}
