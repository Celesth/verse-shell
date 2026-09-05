import QtQuick
import Quickshell
import Quickshell.Io

// Binds the NotifHistory singleton to notif-history.json. Instantiated once,
// by shell.qml, mirroring NotifCacheStore.
Scope {
    FileView {
        id: store

        path: Quickshell.statePath("notif-history.json")
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        adapter: NotifHistory
    }

    Connections {
        target: NotifHistory
        function onSaveRequested() {
            store.writeAdapter();
        }
    }
}
