import QtQuick
import Quickshell.Services.Mpris
import "root:/config"
import "root:/services"

Item {
    id: root
    property MprisPlayer trackedPlayer: null
    readonly property MprisPlayer player: trackedPlayer
        ?? (Mpris.players.count > 0 ? Mpris.players.values[0] : null)
    readonly property bool available: player !== null && (player.trackTitle || "").length > 0
    readonly property string track: available
        ? player.trackTitle + (player.trackArtist ? " — " + player.trackArtist : "") : ""
    property bool expanded: mouse.containsMouse
    implicitWidth: available ? row.implicitWidth : 0
    implicitHeight: 28
    visible: available

    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

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
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Text {
            text: Icons.musicNote
            font.family: Icons.family
            font.pixelSize: Theme.fontSize(13)
            color: root.player?.isPlaying ? Theme.accent : Qt.alpha(Theme.muted, 0.8)
        }
        Text {
            width: 155
            anchors.verticalCenter: parent.verticalCenter
            text: root.track
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(9)
            color: Qt.alpha(Theme.fg, 0.78)
        }
        Item {
            width: root.expanded ? controls.implicitWidth : 16
            height: 24
            clip: true
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Row {
                id: controls
                spacing: 1
                MediaButton { icon: Icons.skipPrevious; available: root.player?.canGoPrevious ?? false; onClicked: root.player?.previous?.() }
                MediaButton { icon: root.player?.isPlaying ? Icons.pause : Icons.playArrow; available: root.player?.canTogglePlaying ?? false; onClicked: root.player?.togglePlaying?.() }
                MediaButton { icon: Icons.skipNext; available: root.player?.canGoNext ?? false; onClicked: root.player?.next?.() }
            }
            Text {
                visible: !root.expanded
                anchors.centerIn: parent
                text: root.player?.isPlaying ? Icons.pause : Icons.playArrow
                font.family: Icons.family; font.pixelSize: Theme.fontSize(12); color: Qt.alpha(Theme.fg, 0.7)
            }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true }

    component MediaButton: Item {
        required property string icon
        required property bool available
        signal clicked()
        width: 20; height: 24
        Text { anchors.centerIn: parent; text: parent.icon; font.family: Icons.family; font.pixelSize: Theme.fontSize(12); color: parent.available ? Theme.fg : Qt.alpha(Theme.muted, 0.35) }
        MouseArea { anchors.fill: parent; enabled: parent.available; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
}
