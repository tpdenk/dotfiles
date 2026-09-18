import QtQuick
import qs

// A short scrolling list of clickable rows: header, rows, empty-state text.
Column {
    id: root

    property string title
    // shown instead of the rows while the model is empty; "" hides it
    property string placeholder
    property alias model: view.model
    property alias delegate: view.delegate
    property alias count: view.count
    // a handful of rows, then scroll: the panel must not grow unbounded
    property int maxHeight: 132

    spacing: 6

    Text {
        visible: root.title !== ""
        text: root.title
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.muted
    }

    ListView {
        id: view
        width: parent.width
        height: Math.min(contentHeight, root.maxHeight)
        visible: count > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
    }

    Text {
        width: parent.width
        visible: root.placeholder !== "" && view.count === 0
        text: root.placeholder
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.muted
    }
}
