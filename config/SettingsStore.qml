import QtQuick
import Quickshell
import Quickshell.Io
import "root:/services"

// Binds the Settings singleton to settings.json. Instantiated once, by
// shell.qml.
Scope {
    id: root

    // Dynamic-theme kickoff must happen exactly once, on the true initial
    // load: onLoaded re-fires on every save, because writeAdapter's own write
    // loops back through the file watcher below.
    property bool themeKicked: false
    // Auto-wallpaper: applied once after the first scan populates the list,
    // when no wallpaper was persisted.
    property bool autoWallpaperFired: false

    FileView {
        id: store

        // system config dir (~/.config/verse/settings.json) so it agrees with
        // the `verse` CLI and a user's hand edits; FileView does not expand
        // "$HOME", so build the absolute path via the env explicitly
        path: Quickshell.env("HOME") + "/.config/verse/settings.json"
        blockLoading: true
        printErrors: false
        // pick up hand edits to settings.json live; without this the daemon
        // keeps its stale in-memory copy and silently overwrites the file on
        // its next save
        watchChanges: true
        onFileChanged: reload()
        adapter: Settings

        onLoaded: {
            // JsonAdapter's load (both the initial parse and any reload() from
            // a hand-edit) writes object/array-typed properties in a way that
            // doesn't reliably emit their changed signal - plain
            // `Settings.pageOrder = [...]` assignments from QML do
            // (LauncherState.movePage reacts instantly), but the load path
            // leaves bindings that depend on these (LauncherState.pageOrder,
            // activePanes) stuck on whatever they last evaluated to, typically
            // the pre-load default. Force a re-notify by reassigning a fresh
            // shallow copy of each.
            Settings.pageOrder = Settings.pageOrder.slice();
            Settings.pages = Object.assign({}, Settings.pages);
            Settings.keybinds = Object.assign({}, Settings.keybinds);
            Settings.flyouts = Object.assign({}, Settings.flyouts);
            Settings.verseAlerts = Object.assign({}, Settings.verseAlerts);
            Settings.clockShow = Object.assign({}, Settings.clockShow);
            Settings.scrambleSections = Object.assign({}, Settings.scrambleSections);
            Settings.heal();
            Settings.loaded();

            if (!root.themeKicked) {
                root.themeKicked = true;
                if (Settings.theme === "matugen")
                    Theme.sampleWallpaper();
            }
            // auto-load a random wallpaper on first boot (no persisted
            // currentWallpaper); deferred until the scan populates the list
            if (!root.autoWallpaperFired && Settings.currentWallpaper === "") {
                if (Wallpapers.list.length > 0) {
                    root.autoWallpaperFired = true;
                    root.applyRandomWallpaper();
                }
            }
        }
    }

    Connections {
        target: Wallpapers
        function onListChanged(): void {
            if (root.autoWallpaperFired || Settings.currentWallpaper !== "")
                return;
            if (Wallpapers.list.length > 0) {
                root.autoWallpaperFired = true;
                root.applyRandomWallpaper();
            }
        }
    }

    function applyRandomWallpaper(): void {
        const walls = Wallpapers.list.filter(w => !w.video);
        if (walls.length === 0) return;
        let pick = walls[Math.floor(Math.random() * walls.length)];
        Settings.currentWallpaper = pick.path;
        Settings.save();
        // apply the wallpaper via the user's wallCommand (verse-wallpaper by
        // default), same path as LauncherWindow.runWallCommand
        Quickshell.execDetached(["bash", "-c", `
            export PATH="$HOME/.local/bin:$PATH"
            WALL='$1' BLUR='$2'
            export WALL BLUR
            exec setsid -w bash -c "$3" >/dev/null 2>&1
        `, "_", pick.path, pick.blur || "", Settings.wallCommand]);
        Theme.sampleWallpaper();
    }

    Connections {
        target: Settings
        function onSaveRequested() {
            store.writeAdapter();
        }
    }

    Component.onCompleted: Settings.heal()
}
