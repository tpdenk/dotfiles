pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.widgets

Dropdown {
    name: "calendar"
    centered: true

    card: PanelCard {
        id: card

        property date shown: firstOf(new Date())
        property date today: new Date()

        implicitWidth: 300
        title: Qt.formatDate(card.shown, "MMMM yyyy")
        subtitle: `week ${isoWeek(card.today)}`

        function firstOf(d: date): date {
            return new Date(d.getFullYear(), d.getMonth(), 1);
        }
        function page(delta: int): void {
            card.shown = new Date(card.shown.getFullYear(), card.shown.getMonth() + delta, 1);
        }
        function isoWeek(d: date): int {
            const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
            t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
            const start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
            return Math.ceil(((t - start) / 86400000 + 1) / 7);
        }

        readonly property var days: {
            const first = card.shown;
            const offset = (first.getDay() + 6) % 7;
            const out = [];
            for (let i = 0; i < 42; i++)
                out.push(new Date(first.getFullYear(), first.getMonth(), 1 - offset + i));
            return out;
        }

        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: card.today = new Date()
        }

        Connections {
            target: Panels

            function onOpenChanged(): void {
                if (Panels.open !== "calendar")
                    return;
                card.today = new Date();
                card.shown = card.firstOf(card.today);
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    {
                        glyph: 0xf0141,
                        delta: -1
                    },
                    {
                        glyph: 0,
                        delta: 0
                    },
                    {
                        glyph: 0xf0142,
                        delta: 1
                    }
                ]

                Pill {
                    required property var modelData
                    glyph: modelData.glyph ? String.fromCodePoint(modelData.glyph) : ""
                    label: modelData.glyph ? "" : "today"
                    glyphColor: Theme.text
                    onClicked: {
                        if (modelData.delta)
                            card.page(modelData.delta);
                        else
                            card.shown = card.firstOf(new Date());
                    }
                }
            }
        }

        Grid {
            id: grid
            columns: 8
            columnSpacing: 0
            rowSpacing: 2

            readonly property real cell: parent.width / 8

            Repeater {
                model: ["wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Text {
                    required property string modelData
                    width: grid.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    color: Theme.muted
                }
            }

            Repeater {
                model: 48

                Item {
                    id: cell
                    required property int index
                    readonly property bool weekCol: index % 8 === 0
                    readonly property date day: card.days[Math.floor(index / 8) * 7 + (weekCol ? 0 : index % 8 - 1)]
                    readonly property bool inMonth: day.getMonth() === card.shown.getMonth()
                    readonly property bool isToday: day.toDateString() === card.today.toDateString()

                    width: grid.cell
                    height: 24

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        visible: cell.isToday
                        color: Theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.weekCol ? card.isoWeek(new Date(cell.day.getFullYear(), cell.day.getMonth(), cell.day.getDate() + 3)) : cell.day.getDate()
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.smallSize
                        font.bold: cell.isToday
                        color: cell.isToday ? Theme.background : cell.weekCol ? Theme.muted : cell.inMonth ? (cell.day.getDay() % 6 === 0 ? Theme.text : Theme.brightText) : Qt.alpha(Theme.muted, 0.6)
                    }
                }
            }
        }

        WheelHandler {
            onWheel: event => card.page(event.angleDelta.y > 0 ? -1 : 1)
        }
    }
}
