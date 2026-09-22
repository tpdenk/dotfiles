import qs.widgets

// Pending package and firmware upgrades, shown under the bar's
// UpdatesIndicator.
Dropdown {
    name: "updates"
    centered: true
    card: UpdatesPanel {}
}
