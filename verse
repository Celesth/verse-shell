#!/usr/bin/env bash
# verse - desktop shell daemon control.
# Adapted from pibble by Kian Blakley (GPLv3).
#   verse start     start the persistent daemon (for spawn-at-startup)
#   verse stop      stop the daemon
#   verse restart   stop, then start
#   verse toggle [page]
#                    show/hide the launcher window (for the keybind),
#                    starting the daemon first if it isn't running; with a
#                    page id (or "settings"), opens straight to that page (or
#                    switches to it if another page is open, or closes if it's
#                    already the one showing)
#   verse settings  open/toggle the settings pane
#   verse replay    re-fire one recent notification; repeated presses step
#                    back through history (see "Replay count" in flyout settings)
#   verse help      show this message (also what a bare `verse` does)
repo="$(dirname "$(readlink -f "$0")")"

# Qt can't switch icon themes at runtime, so quickshell reads QS_ICON_THEME
# at startup; pulled from the launcher's persisted settings. Only called
# right before spawning a new daemon, so a toggle against an already-running
# daemon skips the settings read and gsettings round-trip entirely.
export_icon_theme() {
    settings="$HOME/.config/verse/settings.json"
    theme=$(sed -n 's/.*"iconTheme": *"\([^"]*\)".*/\1/p' "$settings" 2>/dev/null | head -1)
    # no explicit choice: follow the system (GTK) icon theme, since Qt inside a
    # bare layer-shell session can't detect it and would fall back to hicolor
    [ -z "$theme" ] && theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    [ -n "$theme" ] && export QS_ICON_THEME="$theme"
}

# Same problem as export_icon_theme, for fonts: an empty Settings.fontFamily
# ("system default") just leaves Qt's font.family unset, and a bare
# layer-shell client doesn't reliably get the desktop portal's font settings
# the way a normal session app would, so it falls back to fontconfig's raw
# per-request matching instead of one coherent system font. Read GTK's
# monospace font here instead and hand it to Theme.fontFamily as the
# fallback when no explicit choice is set.
export_font_family() {
    settings="$HOME/.config/verse/settings.json"
    font=$(sed -n 's/.*"fontFamily": *"\([^"]*\)".*/\1/p' "$settings" 2>/dev/null | head -1)
    if [ -z "$font" ]; then
        font=$(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null | tr -d "'")
        # gsettings' value usually carries a trailing point size ("JetBrains
        # Mono 11"), but not always (a name-only value is valid too) -
        # Theme.fontFamily wants a bare family name, so only strip the last
        # word if it's actually a number
        last="${font##* }"
        case "$last" in
        '' | *[!0-9]*) ;;
        *) font="${font% *}" ;;
        esac
    fi
    [ -n "$font" ] && export QS_FONT_FAMILY="$font"
}

# Native dialogs (e.g. the settings file picker) only route through
# xdg-desktop-portal - showing the user's actual configured picker instead
# of Qt's generic built-in QML fallback - if told to via this platform
# theme; if the plugin isn't installed Qt just keeps the QML fallback, so
# this is safe to set unconditionally.
export_native_dialogs() {
    export QT_QPA_PLATFORMTHEME=xdgdesktopportal
}

# Qt picks its render loop per platform, and where it falls back to "basic"
# animations no longer run off vsync at all - they advance on a ~16ms timer,
# pinning the whole shell to ~62fps whatever the display does. The proprietary
# NVIDIA driver is what triggers that fallback: on one machine, with only the
# EGL vendor swapped and everything else held fixed, QSG_INFO=1 reports "basic
# render loop" against 10_nvidia.json and "threaded render loop" against
# 50_mesa.json. So this is a no-op on Mesa - Qt already chooses threaded there.
#
# What the fallback costs is the reveal's edge motion, which is the thing that
# actually reads as "skipping". Sampling LauncherState.reveal every presented
# frame on a 5120x2160 120Hz output, over the grow circle's whole travel:
#
#            frame dt (ms)          circle edge travel (px/frame)
#            mean  p95  max         mean   max    peak/avg
#   basic    17.4   25  113          87    312      3.6x
#   threaded  8.9    9  111          42    119      2.8x
#
# The p95 is the number that matters: under basic one frame in twenty lands
# 25ms late, and the edge covers 312px in it against an 87px average - a
# visible jump followed by a crawl. Threaded holds p95 to a single frame and
# halves the per-frame travel, so the same easing curve reads as continuous.
#
# It is not free: threaded also roughly doubles the *duration* of any
# GUI-thread stall (~47ms -> ~90ms worst on a plain open, measured across three
# commits). That is a real cost, but it shows up as a discrete hitch when
# something heavy runs, whereas basic degrades every single frame of every
# reveal. Fix the stalls; keep the frame rate.
#
# Left overridable because "basic" is a deliberate fallback, not an oversight:
# anyone who hits the driver trouble it exists to dodge can put
# QSG_RENDER_LOOP=basic back in the environment and keep it.
export_render_loop() {
    [ -z "$QSG_RENDER_LOOP" ] && export QSG_RENDER_LOOP=threaded
}

# ipc calls fail on ambiguity if duplicate daemons exist; always talk to the
# newest and reap any older duplicates.
ipc() {
    local fn="$1"
    shift
    qs -p "$repo" ipc -n call launcher "$fn" "$@" 2>/dev/null
}
running_pids() {
    pgrep -f "^qs -p $repo\$"
}
reap_duplicates() {
    mapfile -t pids < <(running_pids | sort -n)
    while [ "${#pids[@]}" -gt 1 ]; do
        kill "${pids[0]}" 2>/dev/null
        pids=("${pids[@]:1}")
    done
}
stop_daemon() {
    reap_duplicates
    pids=$(running_pids)
    [ -n "$pids" ] && kill $pids
    rm -f /tmp/verse-daemon.lock
}
# guard: acquire lockfile + set env; caller spawns qs
guard_start() {
    python3 "$repo/verse-guard.py" /tmp/verse-daemon.lock || return 1
    export_icon_theme
    export_font_family
    export_native_dialogs
    export_render_loop
}
# background-ipc: spawn daemon in background, poll until IPC available, then
# run an IPC function. Returns 0 on success.
bg_ipc() {
    local ipc_fn="$1"; shift
    setsid -f qs -p "$repo" >/dev/null 2>&1
    for _ in $(seq 1 50); do
        sleep 0.1
        ipc "$ipc_fn" "$@" && return 0
    done
    return 1
}

# built-in pages plus whatever custom pages are currently uploaded, read
# straight out of settings.json (same file/format export_icon_theme reads)
# so `verse help` always reflects what's actually toggleable right now
list_pages() {
    local settings ids
    settings="$HOME/.config/verse/settings.json"
    # the readable names, not the panes' internal ids ("walls"/"clips" -
    # settings keys that can't be renamed); LauncherState.resolvePageArg
    # maps these back, and still takes the internal ids too
    ids="clock, apps, wallpapers, clipboard"
    if [ -f "$settings" ]; then
        # ids are namespaced "folder:name" (see CustomPages.dir in
        # services/CustomPages.qml); the prefix is internal, so strip it here -
        # the CLI accepts (and this prints) just the bare name, which
        # LauncherState.resolvePageArg maps back to the real id
        custom=$(sed -n '/"uploadedPages"/,/^    \]/ s/.*"id": *"\([^"]*\)".*/\1/p' "$settings" | sed 's/^[^:]*://' | paste -sd, -)
        [ -n "$custom" ] && ids="$ids, ${custom//,/, }"
    fi
    # the settings pane isn't a page (it sits outside the cycle - see
    # LauncherState.activePanes), but it toggles exactly like one, so it's
    # listed here, last, rather than left undiscoverable
    printf '%s' "$ids, settings"
}

usage() {
    cat <<USAGE
verse - desktop shell daemon control
Adapted from pibble by Kian Blakley (GPLv3).

Usage: verse <command>

Commands:
  start     start the persistent daemon (for spawn-at-startup)
  stop      stop the daemon
  restart   stop, then start the daemon
  toggle [page]
            show/hide the launcher window, starting the daemon first if
            needed; with a page id, opens/switches straight to that page
            (or closes if it's already the one showing)
            available: $(list_pages)
  settings  open/toggle the settings pane
  replay    re-fire one recent notification; repeated presses step back
  help      show this message (also what a bare \`verse\` does)
USAGE
}

case "$1" in
start)
    export_icon_theme
    export_font_family
    export_native_dialogs
    export_render_loop
    # clipboard watchers — only if not already running
    if ! pgrep -f "wl-paste.*cliphist" >/dev/null 2>&1; then
        wl-paste --type text --watch cliphist store &
        wl-paste --type image --watch cliphist store &
    fi
    exec python3 "$repo/verse-guard.py" /tmp/verse-daemon.lock qs -p "$repo"
    ;;
stop)
    stop_daemon
    rm -f /tmp/verse-daemon.lock
    exit 0
    ;;
restart)
    stop_daemon
    for _ in $(seq 1 50); do
        running_pids >/dev/null || break
        sleep 0.1
    done
    export_icon_theme
    export_font_family
    export_native_dialogs
    export_render_loop
    # clipboard watchers — only if not already running
    if ! pgrep -f "wl-paste.*cliphist" >/dev/null 2>&1; then
        wl-paste --type text --watch cliphist store &
        wl-paste --type image --watch cliphist store &
    fi
    exec python3 "$repo/verse-guard.py" /tmp/verse-daemon.lock qs -p "$repo"
    ;;
toggle)
    reap_duplicates
    ipc toggle "$2" && exit 0
    # daemon not running: acquire lock, then start qs and poll IPC
    guard_start || exit 1
    bg_ipc toggle "$2" && exit 0
    exit 1
    ;;
settings)
    reap_duplicates
    ipc settings && exit 0
    # daemon not running: acquire lock, then start qs and poll IPC
    guard_start || exit 1
    bg_ipc settings && exit 0
    exit 1
    ;;
replay)
    reap_duplicates
    ipc replay && exit 0
    echo "verse: daemon not running - run 'verse start' first" >&2
    exit 1
    ;;
help | "")
    usage
    ;;
*)
    echo "verse: unknown command '$1'" >&2
    usage >&2
    exit 1
    ;;
esac
