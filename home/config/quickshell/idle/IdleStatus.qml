pragma Singleton
import Quickshell
import QtQuick

// Whether the bar holds the session awake. While set, hypridle sees no idle
// time, so it neither locks nor suspends.
Singleton {
    property bool inhibited: false
}
