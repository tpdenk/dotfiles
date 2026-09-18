pragma Singleton
import Quickshell

// Which dropdown is open, if any. They share the top-right slot, so opening
// one closes the others.
Singleton {
    id: root

    property string open: ""

    function toggle(name: string): void {
        root.open = root.open === name ? "" : name;
    }
    function show(name: string): void {
        root.open = name;
    }
    function close(name: string): void {
        if (root.open === name)
            root.open = "";
    }
}
