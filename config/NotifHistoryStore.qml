import QtQuick
import Quickshell
import Quickshell.Io

// Binds the NotifHistory singleton to a per-session JSON file. It mirrors
// NotifCacheStore, but deliberately points the history at /tmp (a tmpfs that
// Linux flushes on every boot) instead of the persistent state path: the
// notification history is a session log, so each shutdown/reboot starts
// clean. It still survives plain verse daemon restarts within the session.
Scope {
    FileView {
        id: store

        // /tmp is tmpfs on this system — wiped on reboot. Sits next to the
        // other session markers verse keeps there (verse-tint.png). The cache
        // stays persistent; only the history log is per-session.
        path: "/tmp/verse-notif-history.json"
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
