import QtQuick
import qs
import qs.widgets

PanelCard {
    id: root
    title: "Updates"

    Stat {
        width: parent.width
        label: "Packages"
        value: UpdatesStatus.failed ? "unknown" : `${UpdatesStatus.count}`
    }

    Stat {
        width: parent.width
        label: "Builds"
        value: `${UpdatesStatus.groups.length}`
    }

    Stat {
        width: parent.width
        label: "Kernel"
        value: UpdatesStatus.kernelUpdate ? UpdatesStatus.versionLabel(UpdatesStatus.kernel) : "current"
    }

    Text {
        width: parent.width
        visible: UpdatesStatus.kernelUpdate
        text: "The running kernel stays until a reboot; its modules are replaced on disk immediately."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.warning
    }

    Divider {
        width: parent.width
    }

    Item {
        width: parent.width
        implicitHeight: updateAll.implicitHeight

        Pill {
            id: updateAll
            anchors.right: parent.right
            visible: UpdatesStatus.count > 0
            glyph: UpdatesStatus.icon
            label: "Update all"
            labelColor: Theme.brightText
            onClicked: UpdatesStatus.updateAll()
        }
    }

    Divider {
        width: parent.width
    }

    UpdatesPackages {
        width: parent.width
    }
}
