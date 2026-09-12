import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "root:/config"
import "root:/services"
import "root:/ui"

// The scrollable island: one persistent pill whose *content* is four stacked
// modes - 0 Overview (window title + 12h clock, or "MMM d • H:mm AP" when no
// window), 1 Workspaces, 2 System Tray, 3 MPRIS - swapped by scrolling over
// the island. The pill background never leaves; the *layer* under it swaps
// with a directional crossfade (old content slides out one way while the new
// slides in from the other), and its width follows whichever mode is showing
// through one shared Behavior.
//
// Focus is tracked from Quickshell.Hyprland.activeWindow, the clock ticks on a
// 30s timer, and every string that can change while sitting still (window
// title, track title, the time) goes through ui/AnimatedLabel so a swap never
// jumps out from under the morphing pill.
Item {
    id: root

    readonly property int modeOverview: 0
    readonly property int modeWorkspace: 1
    readonly property int modeTray: 2
    readonly property int modeMpris: 3

    implicitHeight: 28
    height: 28

    // ── state source: one place focus → display is decided ──
    readonly property var activeWin: Hyprland.activeWindow
    readonly property string rawTitle: activeWin?.title ?? ""
    readonly property string winClass: activeWin?.class ?? ""
    readonly property url winIcon: activeWin?.icon ?? ""
    readonly property string displayTitle: {
        const t = (rawTitle || "").trim();
        if (t !== "") return t;
        const c = (winClass || "").trim();
        return c !== "" ? c : "";
    }
    readonly property bool hasWindow: displayTitle !== ""

    // ── geometry: width tracks whichever mode's row is showing, clamped ──
    readonly property real minW: 176
    readonly property real maxW: 440
    readonly property real padX: 20
    // the overview row's non-title siblings: window glyph 16 + gaps 8*3 +
    // bullet ~8 + clock label ~80
    readonly property real overviewFixed: 16 + 24 + 8 + 80
    readonly property real titleMax: Math.max(120, root.maxW - root.padX - root.overviewFixed)
    // the mpris row's non-track siblings: state glyph + gaps + divider + the
    // three 20px controls
    readonly property real mprisFixed: 150
    readonly property real trackMax: Math.max(140, root.maxW - root.padX - root.mprisFixed)

    width: Math.min(root.maxW, Math.max(root.minW, root.activeLayer.implicitWidth + root.padX))
    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    clip: true

    // ── which mode is showing, and the four stacked layers over it ──
    property int mode: root.modeOverview
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
        const anim = root.switchAnims[root.layerItems.indexOf(layer)];
        anim.opTo = opacityTo;
        anim.xTo = xTo;
        anim.restart();
    }

    function transitionMode(next: int, dir: int): void {
        if (next === root.mode)
            return;
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
        // pill is clear. The two never overlap, unlike a literal crossfade.
        out.opacity = 1;
        out.x = 0;
        root.setLayerTarget(out, 0, -v * 18);

        inn.opacity = 0;
        inn.x = v * 18;
        enterT.start();
        root.kickAutoReturn();
    }

    // Enter is deferred until the pill has finished reshaping to the new mode
    // (the width Behavior runs for 260ms), so the layout settles before the
    // content fades in instead of the two fighting across the morph.
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
    }
    ParallelAnimation {
        id: workspaceAnim
        property alias opTo: workspaceOpacity.to
        property alias xTo: workspaceX.to
        NumberAnimation { id: workspaceOpacity; target: workspaceLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: workspaceX; target: workspaceLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: trayAnim
        property alias opTo: trayOpacity.to
        property alias xTo: trayX.to
        NumberAnimation { id: trayOpacity; target: trayLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: trayX; target: trayLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: mprisAnim
        property alias opTo: mprisOpacity.to
        property alias xTo: mprisX.to
        NumberAnimation { id: mprisOpacity; target: mprisLayer; property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: mprisX; target: mprisLayer; property: "x"; duration: 220; easing.type: Easing.OutCubic }
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

    // ── shared hover state for the bar's auto-hide buttons ──
    readonly property bool hovered: wheelArea.containsMouse

    // ── the scroller: first child (lowest z), so the modes' own controls sit
    // above it and keep clicks; bare pill space gives wheel (and the overview
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

    // ── 0 · overview: [window icon|calendar] title/date • time ──
    Item {
        id: overviewLayer
        z: 1
        width: parent.width
        height: parent.height
        opacity: 1
        implicitWidth: overviewRow.implicitWidth

        Row {
            id: overviewRow
            anchors.centerIn: parent
            spacing: 8

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16

                Image {
                    anchors.fill: parent
                    visible: root.hasWindow
                    source: root.winIcon
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.hasWindow
                    text: "\ue425"
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(11)
                    color: Qt.alpha(Theme.muted, 0.7)
                }
            }

            AnimatedLabel {
                id: overviewMain
                anchors.verticalCenter: parent.verticalCenter
                content: root.hasWindow ? root.displayTitle : root.dateStr
                color: Theme.fg
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
                maxWidth: root.titleMax
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "•"
                color: Qt.alpha(Theme.muted, 0.55)
                font.pixelSize: Theme.fontSize(11)
                font.family: Theme.fontFamily
            }

            AnimatedLabel {
                id: overviewTime
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeStr
                color: Theme.muted
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
            }
        }
    }

    // ── 1 · workspaces: the shared monitor poll, housing only while here ──
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
                visible: root.player?.canGoPrevious ?? false
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
                visible: root.player?.canTogglePlaying ?? false
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
                visible: root.player?.canGoNext ?? false
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
        dateStr = now.toLocaleDateString(Qt.locale(), "MMM d");
        fullDate = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy");
    }
}