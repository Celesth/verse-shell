pragma Singleton
import QtQuick

// Factory values for every setting that more than one place needs to know:
// Settings declares them as its adapter defaults, and SettingsSchema.reset()
// puts them back. Kept in their own singleton rather than on either of those
// so neither has to import the other (Settings is the store's adapter;
// SettingsSchema writes to Settings), and so "what is the default" has one
// answer instead of a literal repeated at both ends.
QtObject {
    readonly property string wallCommand: 'export PATH="$HOME/.local/bin:$PATH"; verse-wallpaper'
    readonly property string wallpaperDir: "~/Pictures/Wallpapers"
    readonly property bool glassEffect: false
    // how an applied wallpaper is scaled onto the display: "crop" fills the
    // screen and crops overflow, "fit" shows the whole image letterboxed,
    // "center" draws it at native size in the middle
    readonly property string wallpaperFit: "crop"

    readonly property var pages: ({ clock: true, apps: true, walls: true, clips: true, notifs: true, media: true })
    readonly property var pageOrder: ["clock", "apps", "walls", "clips", "notifs", "media"]
    readonly property var clockShow: ({ date: true, battery: true, weather: true })
    // per-page tile grid decorations: the live search query above the tiles,
    // and a page-of-tiles dot indicator below them. Both off out of the box -
    // the grid reads cleaner without them, and neither is load-bearing (the
    // query is echoed by what the grid filters to, the dots by the tiles
    // themselves changing)
    readonly property var pageIndicators: ({ query: false, dots: false })
    readonly property var flyouts: ({ volume: true, notifs: true })
    // per-surface switches for the text scramble, and the whole of that
    // setting (see Anim.scrambleAllowed). One key per surface the user can
    // point at: every built-in page of the launcher's stage, each flyout, the
    // settings pane and the power prompts. All off out of the box - it is much
    // the loudest thing the shell does, so it is opt-in. A custom page has no
    // key here and needs none - an unknown one reads as off too (see
    // Settings.scrambleEnabled).
    readonly property var scrambleSections: ({ clock: false, apps: false, walls: false, clips: false, volume: false, notifs: false, settings: false, power: false, bar: true })
    readonly property var verseAlerts: ({ errors: true, missingDeps: true, actions: true, battery: true })
    readonly property var keybinds: ({
        cycle: "Tab",
        reverseCycle: "Shift+Tab",
        launch: "Return",
        exit: "Escape",
        settings: "Ctrl+S",
        power: "Ctrl+P",
        reboot: "Ctrl+R",
        navLeft: "Left",
        navRight: "Right",
        navUp: "Up",
        navDown: "Down",
        pagePrev: "PageUp",
        pageNext: "PageDown"
    })

    // the retired Mono preset's palette, which the custom theme is seeded from
    readonly property string customAccent: "#cfcfcf"
    readonly property string customFg: "#f0f0f0"
    readonly property string customMuted: "#8a8a8a"

    readonly property int appsCols: 4
    readonly property int appsRows: 3
    readonly property int wallsCols: 3
    readonly property int wallsRows: 3
    readonly property int wallsVisible: 7
    readonly property int clipsCols: 4
    readonly property int clipsRows: 3
    readonly property int clipsMax: 120

    // battery % the low-battery alert fires at (see Battery.checkLevel)
    readonly property int batteryAlertLevel: 5

    readonly property int barPadding: 0
    // the island's side buttons hide until hovered while this is on, and the
    // island drifts back to its overview after autoReturnDelay ms of quiet when
    // autoReturn is on; both off out of the box
    readonly property bool autoHideButtons: false
    readonly property bool autoReturn: false
    readonly property int autoReturnDelay: 4000
    // the mpris mode's prev/toggle/next row; off keeps that mode purely read-only
    readonly property bool showMprisControls: true
    readonly property int hyprBorder: 2
    readonly property int hyprRounding: 8
}
