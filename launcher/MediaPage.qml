import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "root:/config"
import "root:/services"
import "root:/ui"

// The media pane: one panel per player, with the active one's track, seek,
// transport, shuffle/loop and volume controls. Mirrors the other built-in
// panes (clock/apps/clips) - centered, gated on `pane === "media"`, and given
// the shared entrance pop by the launcher itself.
Item {
    id: root

    anchors.fill: parent

    function resetEntrance(): void {
        panel.opacity = 0.004;
    }

    Item {
        id: panel
        anchors.centerIn: parent
        width: 460
        transform: Translate {
            y: LauncherState.powerPull - LauncherState.rebootPull
        }
        opacity: 0.004
        visible: LauncherState.pane === "media"
        onVisibleChanged: if (visible) panelEnter.restart()
        Connections {
            target: LauncherState
            function onPaneChanged() {
                if (LauncherState.pane === "media")
                    panelEnter.restart();
            }
        }

        ParallelAnimation {
            id: panelEnter
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: Anim.tile(200); easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; from: 0.92; to: 1; duration: Anim.tile(500); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        }

        // ── state ──
        readonly property bool hasPlayers: Mpris.players.count > 0

        // Which player the panel drives. `picked` is null until the user (or
        // the auto-lead timer) settles on one; all writes go here so
        // `player` stays a live binding.
        property var picked: null
        readonly property var player: root.panel.hasPlayers
            ? (root.panel.picked ?? (playingPlayer() ?? Mpris.players.values[0]))
            : null

        function playingPlayer() {
            for (let i = 0; i < Mpris.players.count; i++) {
                const p = Mpris.players.values[i];
                if (p.playbackState === MprisPlaybackState.Playing)
                    return p;
            }
            return null;
        }

        // Auto-picks a leading player when the media pane is entered. Only
        // ticks while the pane is actually visible, and stops for good the
        // moment a player is settled on - so instead of firing once a second
        // for the daemon's whole life (a permanent 1Hz wakeup even when the
        // media pane is never opened), it wakes the event loop only for the
        // handful of seconds it takes to settle.
        Timer {
            id: leadTimer
            interval: 1000
            repeat: true
            running: root.panel.visible && root.panel.picked === null
            onTriggered: {
                const p = root.panel;
                if (p.picked !== null || !p.hasPlayers)
                    return;
                if (p.playingPlayer() !== null)
                    p.picked = p.playingPlayer();
                else if (Mpris.players.count > 0 && p.picked === null)
                    p.picked = Mpris.players.values[0];
                if (p.picked !== null)
                    root.leadTimer.stop();
            }
        }

        // ── empty state ──
        Column {
            visible: root.panel.hasPlayers ? false : true
            anchors.centerIn: parent
            width: parent.width
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.musicNote
                color: Qt.alpha(Theme.muted, 0.35)
                font { family: Icons.family; pixelSize: Theme.fontSize(64) }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No media players running"
                color: Theme.muted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize(15) }
            }
        }

        // ── player picker ──
        Column {
            visible: root.panel.hasPlayers
            width: parent.width
            spacing: 10

            Text {
                text: "Players"
                color: Theme.muted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13) }
            }

            Repeater {
                model: Mpris.players
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: modelData === root.panel.player
                    width: root.panel.width
                    height: 34
                    radius: Theme.radius(10)
                    color: hoverArea.containsMouse
                        ? Qt.alpha(Theme.fg, 0.06)
                        : active
                            ? Qt.alpha(Theme.accent, 0.15)
                            : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    border.width: 1
                    border.color: active ? Qt.alpha(Theme.accent, 0.35) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.playbackState === MprisPlaybackState.Playing
                                ? Icons.playArrow : Icons.pause
                            color: active ? Theme.accent : Theme.muted
                            font { family: Icons.family; pixelSize: Theme.fontSize(17) }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.identity
                            elide: Text.ElideRight
                            color: active ? Theme.fg : Theme.muted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSize(14) }
                        }
                    }
                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.panel.picked = modelData
                    }
                }
            }

            // ── active player panel ──
            Rectangle {
                visible: root.panel.player !== null
                width: root.panel.width
                color: Qt.alpha(Theme.surface, 0.5)
                radius: Theme.radius(16)
                border.width: 1
                border.color: Qt.alpha(Theme.muted, 0.15)

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // track identity + art
                    Row {
                        width: parent.width
                        spacing: 14

                        Rectangle {
                            id: artBox
                            width: 76
                            height: 76
                            radius: Theme.radius(14)
                            color: Qt.alpha(Theme.muted, 0.08)
                            clip: true

                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: root.panel.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                visible: artImg.status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: Icons.musicNote
                                color: Qt.alpha(Theme.muted, 0.4)
                                font { family: Icons.family; pixelSize: Theme.fontSize(38) }
                                visible: artImg.status !== Image.Ready
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 90
                            spacing: 4
                            Text {
                                width: parent.width
                                text: root.panel.player?.trackTitle || "Unknown title"
                                elide: Text.ElideRight
                                color: Theme.fg
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSize(18); bold: true }
                            }
                            Text {
                                width: parent.width
                                text: root.panel.player?.trackArtist || ""
                                elide: Text.ElideRight
                                visible: text !== ""
                                color: Theme.muted
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSize(14) }
                            }
                            Text {
                                width: parent.width
                                text: root.panel.player?.trackAlbum || ""
                                elide: Text.ElideRight
                                visible: text !== ""
                                color: Qt.alpha(Theme.muted, 0.7)
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13) }
                            }
                        }
                    }

                    // position / seek
                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            horizontalAlignment: Text.AlignRight
                            text: formatTime(root.panel.player?.position ?? 0)
                            color: Theme.muted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSize(11) }
                        }
                        Rectangle {
                            id: seekTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44 - 44 - 16
                            height: 5
                            radius: 3
                            color: Qt.alpha(Theme.muted, 0.2)
                            Rectangle {
                                height: parent.height
                                width: root.panel.player?.length
                                    ? (root.panel.player.position / root.panel.player.length) * parent.width
                                    : 0
                                radius: 3
                                color: Theme.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: (root.panel.player?.canSeek ?? false)
                                    && (root.panel.player?.positionSupported ?? false)
                                onPressed: seekTo(mouse.x)
                                onPositionChanged: if (pressed) seekTo(mouse.x)
                                function seekTo(x) {
                                    const len = root.panel.player?.length ?? 0;
                                    if (len <= 0 || !root.panel.player) return;
                                    root.panel.player.position = Math.max(0, Math.min(1, x / width)) * len;
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            text: formatTime(root.panel.player?.length ?? 0)
                            color: Theme.muted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSize(11) }
                        }
                    }

                    // shuffle / volume
                    Row {
                        width: parent.width
                        spacing: 12
                        ChipRow {
                            items: [
                                { id: "shuffle", label: "shuffle" }
                            ]
                            isOn: (id) => root.panel.player?.shuffle ?? false
                            toggle: (id) => {
                                if (root.panel.player?.shuffleSupported)
                                    root.panel.player.shuffle = !root.panel.player.shuffle;
                            }
                        }
                        Rectangle {
                            width: 1
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.alpha(Theme.muted, 0.15)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.volumeUp
                            color: Theme.muted
                            font { family: Icons.family; pixelSize: Theme.fontSize(20) }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 110
                            height: 5
                            radius: 3
                            color: Qt.alpha(Theme.muted, 0.2)
                            Rectangle {
                                height: parent.height
                                width: (root.panel.player?.volume ?? 1.0) * parent.width
                                radius: 3
                                color: Theme.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: (root.panel.player?.canControl ?? false)
                                    && (root.panel.player?.volumeSupported ?? false)
                                onPressed: setVol(mouse.x)
                                onPositionChanged: if (pressed) setVol(mouse.x)
                                function setVol(x) {
                                    if (!root.panel.player) return;
                                    root.panel.player.volume = Math.max(0, Math.min(1, x / width));
                                }
                            }
                        }
                    }

                    // transport
                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.LeftToRight

                        MediaButton {
                            icon: Icons.skipPrevious
                            enabled: root.panel.player?.canGoPrevious ?? false
                            onClicked: root.panel.player.previous()
                        }
                        MediaButton {
                            icon: root.panel.player?.isPlaying ? Icons.pause : Icons.playArrow
                            big: true
                            enabled: root.panel.player?.canTogglePlaying ?? false
                            onClicked: root.panel.player.togglePlaying()
                        }
                        MediaButton {
                            icon: Icons.stop
                            enabled: root.panel.player?.canControl ?? false
                            onClicked: root.panel.player.stop()
                        }
                        MediaButton {
                            icon: Icons.skipNext
                            enabled: root.panel.player?.canGoNext ?? false
                            onClicked: root.panel.player.next()
                        }
                    }
                }
            }
        }

        // playback progress ticker (position doesn't update by itself)
        Timer {
            running: root.panel.player?.playbackState === MprisPlaybackState.Playing
            interval: 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: if (root.panel.player && root.panel.player.positionSupported)
                root.panel.player.positionChanged()
        }

        component MediaButton: Rectangle {
            id: btn
            property string icon
            property bool big: false
            signal clicked
            width: big ? 56 : 42
            height: width
            radius: Theme.radius(14)
            color: Qt.alpha(Theme.accent, hover.containsMouse ? 0.24 : 0.12)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.35)
            enabled: true
            opacity: btn.enabled ? 1 : 0.35
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: btn.icon
                color: btn.enabled ? Theme.accent : Theme.muted
                font { family: Icons.family; pixelSize: Theme.fontSize(big ? 24 : 18) }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: btn.enabled
                onClicked: btn.clicked()
            }
        }

        function formatTime(seconds: real): string {
            seconds = Math.max(0, Math.floor(seconds));
            const m = Math.floor(seconds / 60);
            const s = seconds % 60;
            return m + ":" + (s < 10 ? "0" : "") + s;
        }
    }
}
