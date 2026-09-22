import qs.widgets

// Network details, shown under the bar's NetworkIndicator.
Dropdown {
    name: "network"
    // only while a wifi passphrase is being entered
    grabKeyboard: !!NetworkStatus.pendingNetwork
    card: NetworkPanel {}
}
