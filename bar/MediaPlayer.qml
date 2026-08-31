import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "root:/config"
import "root:/services"
import "root:/ui"

// A compact now-playing indicator for the bar, sitting right of the workspace
// dots. Shows a music glyph and "title - artist" for whichever player is
// playing (falling back to the first registered player). Collapses out of the
// row entirely once nothing is playing, and a click toggles play/pause.
Item {
    id: root

    // Whichever player last began playing wins; otherwise fall back to the
    // first registered player so something useful shows even when paused.
    // Mpris.players is an ObjectModel: size via .count, items via .values[].
    property MprisPlayer trackedPlayer: null
    readonly property MprisPlayer player: root.trackedPlayer
        ?? (Mpris.players.count > 0 ? Mpris.players.values[0] : null)

    readonly property bool hasMedia: root.player !== null
        && (root.player.trackTitle || "").length > 0
        && (root.player.playbackState === MprisPlaybackState.Playing
            || root.player.playbackState === MprisPlaybackState.Paused)

    implicitWidth: root.hasMedia ? mediaRow.implicitWidth : 0
    implicitHeight: 20

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // adopt the player that starts playing so playback follows across apps
    Instantiator {
        model: Mpris.players

        Connections {
            required property var modelData
            target: modelData

            function onPlaybackStateChanged() {
                if (modelData.playbackState === MprisPlaybackState.Playing)
                    root.trackedPlayer = modelData;
            }
        }
    }

    Row {
        id: mediaRow
        visible: root.hasMedia
        spacing: 6

        // leading separator, matches the one between launcher and workspaces
        Rectangle {
            width: 1; height: 14
            color: Qt.alpha(Theme.muted, 0.2)
        }

        Text {
            text: "\u266a"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(11)
            color: root.player && root.player.isPlaying
                ? Theme.accent
                : Qt.alpha(Theme.muted, 0.6)
        }

        ScrambleText {
            content: root.player
                ? root.player.trackTitle
                    + (root.player.trackArtist ? " - " + root.player.trackArtist : "")
                : ""
            color: Theme.muted
            font.pixelSize: Theme.fontSize(11)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 220)
            maximumLineCount: 1
            scrambleSection: "bar"
            followsPane: false
            replayOnChange: true
            opacity: 0.85
        }
    }

    // click overlay - kept outside the Row so it doesn't confuse Row layout
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.hasMedia
        onClicked: {
            if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying();
        }
    }
}
