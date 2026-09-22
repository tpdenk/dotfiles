import QtQuick
import qs
import qs.widgets

// The power card: uptime, battery, profile, and what everything is drawing.
PanelCard {
    title: "Power"

    Stat {
        width: parent.width
        label: "Uptime"
        value: PowerStatus.uptime
    }

    Stat {
        width: parent.width
        label: "Battery"
        value: PowerStatus.batteryLabel
    }

    Stat {
        width: parent.width
        label: PowerStatus.charging ? "Charge rate" : "Discharge rate"
        value: PowerStatus.rateLabel
    }

    Divider {
        width: parent.width
    }

    LabeledRow {
        width: parent.width
        label: "Profile"

        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            enabled: PowerStatus.profilesAvailable
            options: PowerStatus.profiles.map(entry => entry.label)
            current: PowerStatus.profileIndex
            onSelected: index => PowerStatus.setProfile(index)
        }
    }

    // a dead switch with no explanation reads as a bug in the shell
    Text {
        width: parent.width
        visible: !PowerStatus.profilesAvailable
        text: "power-profiles-daemon is not running"
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.accentSecondary
    }

    Divider {
        width: parent.width
    }

    PowerDraw {
        width: parent.width
    }
}
