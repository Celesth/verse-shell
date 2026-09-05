pragma Singleton
import QtQuick
import Quickshell.Io

// The notification center's history, most recent first, persisted as JSON so
// it survives daemon restarts (the launcher's notification pane stays
// populated instead of going blank every time the shell restarts). Each entry
// is a display snapshot - summary, body, app, icon, glyph, timestamp, read -
// exactly what NotificationPage renders; no live NotificationServer objects
// are kept. Capped at Notifier.historyCapacity, so the on-disk record and the
// in-memory list both stay small.
//
// Split from its FileView the same way NotifCache/Settings are: this adapter
// only carries the `items` key (every property on a JsonAdapter is a key in
// the file it backs), and NotifHistoryStore wires it to notif-history.json.
JsonAdapter {
    id: store

    signal saveRequested

    property var items: []

    function save(): void {
        store.saveRequested();
    }
}
