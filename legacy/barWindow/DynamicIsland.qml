import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "root:/config"
import "root:/services"
import "root:/ui"

// The HUD's changeable center: one surface whose *content* is four stacked
// modes - 0 Overview (workspaces · active title · date/time, all in the one
// floating panel), 1 Workspaces (the indicator alone, spread out), 2 System
// Tray, 3 MPRIS - swapped by scrolling over the island. The floating panel
// frame never leaves (that is BarWindow's job now); only this content layer
// swaps, with a directional crossfade (old slides out one way while the new
// slides in from the other), and the panel width follows whichever mode is
// showing through one shared Behavior - a subtle resize, not a morph.
//
// Focus is tracked from Quickshell.Hyprland.activeWindow, the clock ticks on a
// 30s timer, and every string that can change while sitting still (window
// title, track title, the time) goes through ui/AnimatedLabel so a swap never
// jumps out from under the panel.
Item {
    id: root

    readonly property int modeOverview: 0
    readonly property int modeWorkspace: 1
    readonly property int modeTray: 2
    readonly property int modeMpris: 3

    implicitHeight: 30
    height: 30

    // ── state source: one place focus → display is decided ──
    // Quickshell.Hyprland.activeWindow is the reactive focused window; `.title`
    // is what the compositor reports, `.class` is its app class. All UI reads
    // displayTitle, never the model, so the fallback lives in exactly one place.
    readonly property var focusedWindow: Hyprland.activeWindow
    property string activeTitle: focusedWindow?.title ?? ""
    readonly property string appClass: focusedWindow?.class ?? ""
    // title → class → "Desktop"; guaranteed to resolve to a string, never
    // undefined/null/"[object Object]"
    readonly property string displayTitle: {
        const t = (root.activeTitle || "").trim();
        if (t !== "") return t;
        const c = (root.appClass || "").trim();
        return c !== "" ? c : "Desktop";
    }

    // ── geometry: width tracks whichever mode's content is showing, clamped ──
    // The island sits between BarWindow's launcher and notification/settings
    // clusters inside the floating panel, so it only needs to be as wide as its
    // own content; the panel itself clamps to the HUD's 420-900px band.
    readonly property real minW: 320
    readonly property real maxW: 700
    readonly property real padX: 20
    // The overview's three zones: workspaces (left) / active title (centered) /
    // date + time (right). Flank widths come from the actual rendered labels
    // (TextMetrics matching Date/Time exactly), so the panel tracks the real
    // widths ("SEP 3" vs "SEP 13", "9:25 PM" vs "11:59 PM"). overviewGap is the
    // breathing room between zones; titleBand caps the title so a long title
    // elides instead of ever shoving the flanks off the panel ends.
    readonly property real overviewGap: 14
    readonly property real wsW: wsOverview.implicitWidth
    readonly property real dateW: Math.min(ovDateMetrics.advanceWidth, 80)
    readonly property real timeW: Math.min(ovTimeMetrics.advanceWidth, 90)
    // the dt row's chrome on top of date+time: the diamond glyph, three 7px
    // spacings and the interposed "·" (matches dtRow's layout below)
    readonly property real dtW: root.dateW + root.timeW + 36
    readonly property real titleBand: Math.max(140,
        Math.min(320, root.maxW - root.wsW - root.dtW - 2 * root.overviewGap))
    readonly property real overviewRowW: root.wsW + root.overviewGap
        + Math.min(root.titleW, root.titleBand)
        + root.overviewGap + root.dtW
    // the mpris row's non-track siblings: state glyph + gaps + divider + the
    // three 20px controls
    readonly property real mprisFixed: 150
    readonly property real trackMax: Math.max(160,
        Math.min(340, root.maxW - root.padX - root.mprisFixed))

    TextMetrics {
        id: ovDateMetrics
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize(11) }
        text: root.dateStr
    }
    TextMetrics {
        id: ovTimeMetrics
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize(11) }
        text: root.timeStr
    }
    TextMetrics {
        id: ovTitleMetrics
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize(12) }
        text: root.displayTitle
    }
    readonly property real titleW: Math.min(ovTitleMetrics.advanceWidth, root.titleBand)

    width: Math.min(root.maxW, Math.max(root.minW, root.activeLayer.implicitWidth + root.padX))
    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    clip: true

    // ── which mode is showing, and the four stacked layers over it ──
    property int mode: root.modeOverview
    // one wheel gesture = exactly one mode change: while a transition is running
    // (out fade → width morph → in fade) further wheel events are swallowed, never
    // queued, so two modes can never be caught visibly stacked. Only the incoming
    // fade's natural completion clears it (transitionSettled below).
    property bool modeTransitioning: false
    // marks the *latest* setLayerTarget call as an enter (1) vs an out (0), so
    // the per-layer anims' shared onFinished knows whether to release the lock
    property bool entering: false
    readonly property var layerItems: [overviewLayer, workspaceLayer, trayLayer, mprisLayer]
    readonly property Item activeLayer: root.layerItems[root.mode]

    // scrolling cycles the last, effective mode list so MPRIS (and its entry)
    // drops out when no player has anything to show. Overview/Workspace/Tray
    // are always on.
    readonly property var effectiveModes: root.hasMedia
        ? [root.modeOverview, root.modeWorkspace, root.modeTray, root.modeMpris]
        : [root.modeOverview, root.modeWorkspace, root.modeTray]

    // ── mpris player adoption (see MediaPlayer): whichever player starts
    // playing wins, otherwise the first registered player shows while paused ──
    property MprisPlayer tracked: null
    readonly property MprisPlayer player: root.tracked
        ?? (Mpris.players.count > 0 ? Mpris.players.values[0] : null)
    readonly property bool hasMedia: root.player !== null
        && (root.player.trackTitle || "").length > 0
        && (root.player.playbackState === MprisPlaybackState.Playing
            || root.player.playbackState === MprisPlaybackState.Paused)
    readonly property string trackText: root.player
        ? root.player.trackTitle
            + (root.player.trackArtist ? " - " + root.player.trackArtist : "")
        : ""
    readonly property bool isPlaying: root.player?.isPlaying ?? false

    Instantiator {
        model: Mpris.players

        Connections {
            required property var modelData
            target: modelData

            function onPlaybackStateChanged() {
                if (modelData.playbackState === MprisPlaybackState.Playing)
                    root.tracked = modelData;
            }
        }
    }
    onEffectiveModesChanged: {
        // the player vanished mid-mode: fall back to overview rather than sit
        // on a mode the wheel can no longer reach
        if (!root.effectiveModes.includes(root.mode))
            root.transitionMode(root.modeOverview, -1);
    }

    // ── per-layer swipes, driven imperatively (never bound to mode) ──
    // Each ParallelAnimation owns one layer's opacity + x, and its targets are
    // set per transition, so restarting one mid-flight reroutes it cleanly and
    // rapid scrolls converge instead of queuing.
    readonly property var switchAnims: [overviewAnim, workspaceAnim, trayAnim, mprisAnim]

    function setLayerTarget(layer: Item, opacityTo: real, xTo: real): void {
        root.entering = opacityTo >= 1;
        const anim = root.switchAnims[root.layerItems.indexOf(layer)];
        anim.opTo = opacityTo;
        anim.xTo = xTo;
        anim.restart();
    }

    // the per-layer anims all finish through here; only an *enter* completion is
    // allowed to drop the lock (the out fade finishing must not), and the full
    // out + width-morph + in sequence has to have played out by then.
    function transitionSettled(): void {
        if (!root.entering)
            return;
        root.entering = false;
        root.modeTransitioning = false;
    }

    function transitionMode(next: int, dir: int): void {
        if (next === root.mode)
            return;
        if (root.modeTransitioning)
            return;
        root.modeTransitioning = true;
        const v = dir >= 0 ? 1 : -1;
        const oldIdx = root.mode;
        root.mode = next;
        for (const anim of root.switchAnims)
            anim.stop();
        enterT.stop();

        const out = root.layerItems[oldIdx];
        const inn = root.layerItems[next];
        // the outgoing layer always rests hidden, and the incoming one has
        // always been hidden until now (see the layers' resting opacity: 0) -
        // so a switch is: old fades out alone, then the new slides in once the
        // panel is clear. The two never overlap, unlike a literal crossfade.
        out.opacity = 1;
        out.x = 0;
        root.setLayerTarget(out, 0, -v * 18);

        inn.opacity = 0;
        inn.x = v * 18;
        enterT.start();
        root.kickAutoReturn();
    }

    // Enter is deferred until the panel has finished reshaping to the new mode
    // (the width Behavior runs for 260ms), so the layout settles before the
    // content fades in instead of the two fighting across the resize.
    // Restarted (not re-armed) by the next transition, so rapid scrolling only
    // ever schedules the newest mode's entrance.
    Timer {
        id: enterT
        interval: 280
        repeat: false
        onTriggered: root.setLayerTarget(root.activeLayer, 1, 0)
    }

    function cycleMode(step: int): void {
        const eff = root.effectiveModes;
        let cur = eff.indexOf(root.mode);
        if (cur < 0)
            cur = 0;
        const next = eff[(cur + step + eff.length) % eff.length];
        root.transitionMode(next, step);
    }

    ParallelAnimation {
        id: overviewAnim
        property alias opTo: overviewOpacity.to
        property alias xTo: overviewX.to
        NumberAnimation { id: overviewOpacity; target: overviewLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: overviewX; target: overviewLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
        onFinished: root.transitionSettled()
    }
    ParallelAnimation {
        id: workspaceAnim
        property alias opTo: workspaceOpacity.to
        property alias xTo: workspaceX.to
        NumberAnimation { id: workspaceOpacity; target: workspaceLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: workspaceX; target: workspaceLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
        onFinished: root.transitionSettled()
    }
    ParallelAnimation {
        id: trayAnim
        property alias opTo: trayOpacity.to
        property alias xTo: trayX.to
        NumberAnimation { id: trayOpacity; target: trayLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: trayX; target: trayLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
        onFinished: root.transitionSettled()
    }
    ParallelAnimation {
        id: mprisAnim
        property alias opTo: mprisOpacity.to
        property alias xTo: mprisX.to
        NumberAnimation { id: mprisOpacity; target: mprisLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: mprisX; target: mprisLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
        onFinished: root.transitionSettled()
    }

    // ── auto-return: optional drift back to overview after a quiet spell ──
    Timer {
        id: autoReturnT
        interval: Settings.autoReturnDelay
        repeat: false
        running: false
        onTriggered: root.transitionMode(root.modeOverview, -1)
    }
    onModeChanged: root.kickAutoReturn()
    function kickAutoReturn(): void {
        if (!Settings.autoReturn)
            return;
        autoReturnT.stop();
        if (root.mode !== root.modeOverview)
            autoReturnT.start();
    }

    // ── shared hover state for the panel's auto-hide buttons ──
    readonly property bool hovered: wheelArea.containsMouse

    // ── the scroller: first child (lowest z), so the modes' own controls sit
    // above it and keep clicks; bare panel space gives wheel (and the overview
    // gives its calendar click) to this area.
    MouseArea {
        id: wheelArea
        anchors.fill: parent
        z: 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.mode === root.modeOverview)
                Quickshell.execDetached(["notify-send", "-a", "verse", "-t", "5000", "Calendar", root.fullDate]);
        }
        onWheel: function(wheel) {
            const vertical = Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x);
            if (!vertical)
                return;
            root.cycleMode(wheel.angleDelta.y < 0 ? 1 : -1);
        }
    }

    // ── 0 · overview: workspaces (left) · active title (centered) · date/time (right) ──
    // The three zones of the resting HUD read as one panel: the workspace
    // indicator anchors left, the date/time pair anchor right, and the title
    // band sits centered on the whole thing so it stays pinned to the visual
    // middle no matter how wide the flanks get. Thin accent ticks between the
    // zones are the only chrome. The title always resolves via displayTitle
    // (title → class → "Desktop"); titleBand caps how far it may grow before
    // eliding. Two very light polls: wsOverview only while this mode is showing,
    // wsMode (the spread-out view) only while mode 1 is - never both at once.
    Item {
        id: overviewLayer
        z: 1
        width: parent.width
        height: parent.height
        opacity: 1

        // the panel width comes from these exactly; see the root geometry block
        implicitWidth: root.overviewRowW

        Workspaces {
            id: wsOverview
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            active: root.mode === root.modeOverview
        }

        Rectangle {
            anchors.left: wsOverview.right
            anchors.leftMargin: root.overviewGap / 2 - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Qt.alpha(Theme.accent, 0.16)
        }

        AnimatedLabel {
            id: ovTitle
            anchors.centerIn: parent
            content: root.displayTitle
            color: Theme.fg
            font.pixelSize: Theme.fontSize(12)
            font.family: Theme.fontFamily
            maxWidth: root.titleBand
        }

        Rectangle {
            anchors.right: dtRow.left
            anchors.rightMargin: root.overviewGap / 2 - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Qt.alpha(Theme.accent, 0.16)
        }

        Row {
            id: dtRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            // sparse marker the panel uses so the time doesn't float alone
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u25c7"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(9)
                color: Qt.alpha(Theme.accent, 0.65)
            }

            AnimatedLabel {
                id: ovDate
                anchors.verticalCenter: parent.verticalCenter
                content: root.dateStr
                color: Qt.alpha(Theme.muted, 0.95)
                font.pixelSize: Theme.fontSize(11)
                font.family: Theme.fontFamily
                maxWidth: root.dateW
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u00b7"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Qt.alpha(Theme.muted, 0.45)
            }

            AnimatedLabel {
                id: ovTime
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeStr
                color: Theme.fg
                opacity: 0.9
                font.pixelSize: Theme.fontSize(11)
                font.family: Theme.fontFamily
                maxWidth: root.timeW
            }
        }
    }

    // ── 1 · workspaces: the dedicated view, sharing the same polling data ──
    Item {
        id: workspaceLayer
        z: 1
        width: parent.width
        height: parent.height
        opacity: 0
        implicitWidth: workspaceRow.implicitWidth

        Row {
            id: workspaceRow
            anchors.centerIn: parent
            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                active: root.mode === root.modeWorkspace
            }
        }
    }

    // ── 2 · system tray: every item, as a row with the usual interactions ──
    Item {
        id: trayLayer
        z: 1
        width: parent.width
        height: parent.height
        opacity: 0
        implicitWidth: SystemTray.items.count > 0 ? trayRow.implicitWidth : trayEmpty.implicitWidth

        QsMenuAnchor {
            id: trayMenuAnchor
            anchor.window: root.Window.window
        }

        Row {
            id: trayRow
            anchors.centerIn: parent
            visible: SystemTray.items.count > 0
            spacing: 4

            Repeater {
                model: SystemTray.items

                Item {
                    required property SystemTrayItem modelData

                    width: 22
                    height: 22

                    property bool hovered: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: parent.hovered
                            ? Qt.alpha(Theme.accent, 0.18)
                            : (modelData.status === Status.NeedsAttention
                                ? Qt.alpha(Theme.accent, 0.12)
                                : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: modelData.icon
                        smooth: false
                        mipmap: false
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }

                    TrayPopup {
                        anchorItem: parent
                        tipTitle: modelData.title || modelData.tooltipTitle || modelData.id
                        tipHasMenu: modelData.hasMenu
                        hovered: parent.hovered
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false

                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) {
                                modelData.activate();
                            } else if (mouse.button === Qt.MiddleButton) {
                                modelData.secondaryActivate();
                            } else if (mouse.button === Qt.RightButton) {
                                if (modelData.hasMenu) {
                                    trayMenuAnchor.menu = modelData.menu;
                                    trayMenuAnchor.open();
                                }
                            }
                        }

                        onWheel: function(wheel) {
                            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
                            const delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y;
                            if (delta !== 0)
                                modelData.scroll(delta, horizontal);
                        }
                    }
                }
            }
        }

        AnimatedLabel {
            id: trayEmpty
            visible: SystemTray.items.count === 0
            anchors.centerIn: parent
            content: "no tray applications"
            color: Qt.alpha(Theme.muted, 0.7)
            font.pixelSize: Theme.fontSize(11)
            font.family: Theme.fontFamily
        }
    }

    // ── 3 · mpris: state glyph + track • prev/toggle/next ──
    Item {
        id: mprisLayer
        z: 1
        width: parent.width
        height: parent.height
        opacity: 0
        implicitWidth: root.hasMedia ? mprisRow.implicitWidth : mprisEmpty.implicitWidth

        Row {
            id: mprisRow
            visible: root.hasMedia
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.isPlaying ? "\u266b" : "\u266a"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: root.isPlaying ? Theme.accent : Qt.alpha(Theme.muted, 0.6)
            }

            AnimatedLabel {
                id: trackLabel
                anchors.verticalCenter: parent.verticalCenter
                content: root.trackText
                color: Theme.muted
                font.pixelSize: Theme.fontSize(11)
                font.family: Theme.fontFamily
                maxWidth: root.trackMax
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Qt.alpha(Theme.muted, 0.2)
            }

            // ── prev / play-pause / next ──
            Rectangle {
                id: prevBtn
                anchors.verticalCenter: parent.verticalCenter
                visible: (Settings.showMprisControls ?? true) && (root.player?.canGoPrevious ?? false)
                width: 20
                height: 20
                radius: height / 2
                color: prevBtnArea.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.fg, 0.06)
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.skipPrevious
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.fg
                    opacity: prevBtnArea.containsMouse ? 1 : 0.7
                }
                MouseArea {
                    id: prevBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.previous?.()
                }
            }

            Rectangle {
                id: toggleBtn
                anchors.verticalCenter: parent.verticalCenter
                visible: (Settings.showMprisControls ?? true) && (root.player?.canTogglePlaying ?? false)
                width: 20
                height: 20
                radius: height / 2
                color: toggleBtnArea.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.fg, 0.06)
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? Icons.pause : Icons.playArrow
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.accent
                    opacity: toggleBtnArea.containsMouse ? 1 : 0.7
                }
                MouseArea {
                    id: toggleBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.togglePlaying?.()
                }
            }

            Rectangle {
                id: nextBtn
                anchors.verticalCenter: parent.verticalCenter
                visible: (Settings.showMprisControls ?? true) && (root.player?.canGoNext ?? false)
                width: 20
                height: 20
                radius: height / 2
                color: nextBtnArea.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.fg, 0.06)
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.skipNext
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.fg
                    opacity: nextBtnArea.containsMouse ? 1 : 0.7
                }
                MouseArea {
                    id: nextBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.next?.()
                }
            }
        }

        Row {
            id: mprisEmpty
            visible: !root.hasMedia
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "\u266a"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Qt.alpha(Theme.muted, 0.5)
            }
            AnimatedLabel {
                anchors.verticalCenter: parent.verticalCenter
                content: "nothing playing"
                color: Qt.alpha(Theme.muted, 0.7)
                font.pixelSize: Theme.fontSize(11)
                font.family: Theme.fontFamily
            }
        }
    }

    // ── clock data: once a minute is plenty for a minutes-only clock ──
    property string timeStr: ""
    property string dateStr: ""
    property string fullDate: ""

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.updateTime()
        Component.onCompleted: root.updateTime()
    }

    function updateTime() {
        const now = new Date();
        timeStr = now.toLocaleTimeString(Qt.locale(), "h:mm AP");
        dateStr = now.toLocaleDateString(Qt.locale(), "MMM d").toUpperCase();
        fullDate = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy");
    }
}