pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    function record(key: string): void {
        const uses = Object.assign({}, adapter.uses);
        const entry = uses[key] ?? {
            count: 0,
            last: 0
        };
        uses[key] = {
            count: entry.count + 1,
            last: Date.now()
        };
        adapter.uses = uses;
        file.writeAdapter();
    }

    function score(key: string): real {
        const entry = adapter.uses[key];
        if (!entry)
            return 0;
        const days = (Date.now() - entry.last) / 86400000;
        const weight = days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5;
        return Math.min(99, entry.count * weight);
    }

    FileView {
        id: file
        path: Quickshell.statePath("launcher.json")
        onLoadFailed: Quickshell.execDetached(["mkdir", "-p", Quickshell.stateDir])

        JsonAdapter {
            id: adapter
            property var uses: ({})
        }
    }
}
