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

    Item {
        width: parent.width
        implicitHeight: Math.max(profileLabel.implicitHeight, profileSwitch.implicitHeight)

        Text {
            id: profileLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "Profile"
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }

        Segmented {
            id: profileSwitch
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
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
