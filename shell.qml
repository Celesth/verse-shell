//@ pragma UseQApplication
// verse - a desktop shell for wlr-layer-shell compositors.
// Adapted from pibble (https://github.com/not-pibble/pibble) by Kian Blakley.
// Original code licensed under GPLv3; this derivative respects that license.
// Modifications by celesth for hyprland + kitty + fish + starship.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "root:/config"
import "root:/flyouts"
import "root:/launcher"
import "root:/services"
import "root:/startup"
import "root:/bar"
import "root:/wallpaper"

// This file is only the wiring: it binds the three persisted stores to disk,
// puts up the four windows, and exposes the IPC the `verse` script talks to.
// Everything else lives under:
//
//   config/    persisted settings and what the settings UI knows about them
//   services/  the shell's data sources - theme, wallpapers, clipboard, apps…
//   ui/        reusable settings controls, and the custom-page contract
//   launcher/  the launcher window, its state, and one file per pane
//   flyouts/   the volume and notification OSDs
//   startup/   invisible surfaces that only exist to measure the output
//
// Those layers only ever point one way - launcher/flyouts → ui → services →
// config - which is what keeps the directories acyclic.
ShellRoot {
    id: root

    // Adapters are singletons (so every reference is a plain `Settings.foo`);
    // these bind them to their files. A singleton can't be reparented into a
    // FileView's default property, which is why the two halves live apart.
    SettingsStore {}
    NotifCacheStore {}
    LaunchCountsStore {}

    // Each of these is a distinct wlr-layer-shell surface with its own
    // namespace, so a compositor can carry per-window rules (blur, in
    // particular) for them independently. See README.md for the table.
    LauncherWindow {
        id: launcher
    }
    BarWindow {}
    WallpaperWindow {}
    AppsPanel {}
    VolumeOsd {}
    NotificationFlyout {}

    XrayScaleProbe {}

    // The shell runs as a persistent daemon; the launcher window is toggled
    // over IPC - `qs -p <repo> ipc call launcher toggle`, which is what the
    // `verse` script wraps.
    IpcHandler {
        target: "launcher"

        // `page` is "" for a plain toggle (`verse toggle`) or a pane id for
        // `verse toggle <page>`. Closed: opens straight onto that page. Open
        // and already showing it: closes, so re-pressing the same page's
        // keybind acts like a normal toggle. Open and showing something else:
        // switches to it and stays open - a different page's keybind reads as
        // "take me there", not "close everything".
        function toggle(page: string): void {
            if (page === "apps") {
                if (launcher.shown)
                    launcher.exit();
                else
                    LauncherState.barAppsOpen = !LauncherState.barAppsOpen;
                return;
            }
            const target = LauncherState.resolvePageArg(page);
            if (launcher.shown && !LauncherState.exiting) {
                if (target && LauncherState.pane !== target)
                    LauncherState.setPane(target);
                else
                    launcher.exit();
            } else {
                launcher.open(target);
            }
        }
        // "show" would collide with the `qs ipc show` CLI subcommand
        function open(): void {
            if (!launcher.shown || LauncherState.exiting)
                launcher.open("");
        }
        function close(): void {
            if (launcher.shown)
                launcher.exit();
        }
        // `verse replay`: steps back one more cached notification (up to
        // Settings.replayCount deep) and re-fires just that one, independent of
        // whether the launcher window itself is open.
        function replay(): void {
            Notifier.replay();
        }
        function settings(): void {
            if (launcher.shown && LauncherState.pane === "settings") {
                launcher.exit();
            } else {
                LauncherState.setPane("settings");
                if (!launcher.shown)
                    launcher.open("settings");
            }
        }
    }
}
