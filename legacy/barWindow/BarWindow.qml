import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "root:/config"
import "root:/launcher"
import "root:/services"
import "root:/ui"

// The bar, rebuilt as a detached floating HUD: a near-black panel that hovers
// top-center with clear air on every side instead of latching onto a screen
// edge. Only the top edge is anchored, and it sits down by topMargin, so the
// compositor centers it on the output and leaves visible margins all around -
// nothing here spans the screen or reserves a full-width strip.
//
// Inside sits the changeable center: the scroll-cycling island from
// DynamicIsland.qml (overview / workspaces / system tray / MPRIS, all four
// staying within the one floating panel). The launcher lives left of it,
// notifications + settings on the right; "Auto-hide bar buttons" folds those
// away unless the pointer reaches the panel. The chrome leans toward Wuthering
// Waves but stays plain QML primitives: charcoal glass, a gray-cyan border
// that brightens on hover, bracket ticks at the corners, and a partial accent
// line along the bottom edge.
PanelWindow {
    id: root

    anchors {
        top: true
    }
    margins {
        top: root.topMargin
    }
    // Window surfaces are sized through the implicit hints, not `width`
    // (setting width on a shell window is deprecated and ignored, which leaves
    // the surface 0 wide). The binding here follows hudWrapper.width - itself
    // Behavior-animated - so the surface tracks the panel resize every frame.
    implicitHeight: root.hudHeight
    implicitWidth: hudWrapper.width

    visible: Settings.barEnabled

    property bool appsOpen: LauncherState.barAppsOpen

    // The HUD's geometry contract: a floating panel, never glued to a side.
    // topMargin mixes a fixed hover distance (how far it floats from the top
    // edge) with Settings.barPadding so the settings slider stays meaningful.
    readonly property real topMargin: 18 + Settings.barPadding
    readonly property int hudHeight: 46

    // clamp the panel into the HUD band; content can pull it wider (a long MPRIS
    // track, a full date/title row) but never past these bounds
    readonly property real hudMinW: 420
    readonly property real hudMaxW: 900

    color: "transparent"

    // Liquid glass: when the transparency effect is on the compositor blurs
    // exactly the panel behind it (ext-background-effect-v1). The region follows
    // the panel's geometry - including the animated width - so the blur keeps in
    // step with every resize and never bleeds into the transparent surround.
    BackgroundEffect.blurRegion: Settings.glassEffect ? hudGlassRegion : null

    Region {
        id: hudGlassRegion
        item: hudWrapper
        radius: Theme.radius(14)
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "verse-bar"
    WlrLayershell.exclusiveZone: Settings.barExclusive ? root.topMargin + root.hudHeight : 0
    exclusionMode: Settings.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // One hover pulse for the whole panel: any aim over the frame (the scroller
    // in the island, a utility button, or bare panel padding) counts, and drives
    // both the toolbar reveal and the border/accent brighten.
    readonly property bool hudHovered: hudHoverArea.containsMouse
        || island.hovered
        || launcherArea.containsMouse
        || notifArea.containsMouse
        || settingsArea.containsMouse

    // Auto-hidden utilities are width 0 while away but still laid out with the
    // row's spacing; the HUD's min-width clamp keeps that from reading as odd
    // extra padding, and the panel stays centered either way.
    readonly property bool utilVisible: !Settings.autoHideButtons || root.hudHovered

    readonly property color restBorder: Qt.rgba(0.43, 0.52, 0.60, 0.16)
    readonly property color hoverBorder: Qt.rgba(0.53, 0.68, 0.78, 0.48)

    // ── the floating panel ──
    Item {
        id: hudWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(root.hudMinW, Math.min(root.hudMaxW, hudPadX * 2 + hudRow.implicitWidth))
        height: root.hudHeight

        readonly property real hudPadX: 14

        // the panel resizes in step with the island's content instead of
        // snapping - a subtle follow, not an island morph
        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        // frame-wide hover catcher: lowest of the interactive siblings, so the
        // island's scroller and the utility buttons above it keep every click
        MouseArea {
            id: hudHoverArea
            anchors.fill: parent
            hoverEnabled: true
        }

        // ── the chrome: charcoal glass, border, ticks, accent ──
        Rectangle {
            id: panelBg
            anchors.fill: parent
            radius: Theme.radius(14)
            color: Settings.glassEffect ? Qt.alpha(Theme.surface, 0.5) : Qt.alpha(Theme.surface, 0.94)
            border.width: 1
            border.color: root.hudHovered ? root.hoverBorder : root.restBorder

            Behavior on border.color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // cheap depth: a bright hairline under the top border reads as the
            // panel catching light, no expensive shadow pass
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // ── angular bracket ticks at the corners ──
            // each corner gets an L of two hairlines, inching in from the edge;
            // the top pair is a touch brighter than the bottom pair
            Rectangle { x: 3; y: 3; width: 7; height: 1; color: Qt.alpha(Theme.accent, 0.4) }
            Rectangle { x: 3; y: 3; width: 1; height: 7; color: Qt.alpha(Theme.accent, 0.4) }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 4; y: 3; width: 7; height: 1; color: Qt.alpha(Theme.accent, 0.4) }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 3; y: 3; width: 1; height: 7; color: Qt.alpha(Theme.accent, 0.4) }
            Rectangle { x: 3; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; width: 7; height: 1; color: Qt.alpha(Theme.accent, 0.24) }
            Rectangle { x: 3; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; width: 1; height: 7; color: Qt.alpha(Theme.accent, 0.24) }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 4; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; width: 7; height: 1; color: Qt.alpha(Theme.accent, 0.24) }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 3; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; width: 1; height: 7; color: Qt.alpha(Theme.accent, 0.24) }

            // ── segmented accent along the lower edge ──
            // two short bars hugging the corners, accent-tinted, brightening a
            // notch while the pointer is over the panel
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 1
                anchors.leftMargin: parent.width * 0.16
                width: parent.width * 0.2
                height: 2
                radius: 1
                color: Qt.alpha(Theme.accent, root.hudHovered ? 0.9 : 0.55)

                Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: 1
                anchors.rightMargin: parent.width * 0.16
                width: parent.width * 0.2
                height: 2
                radius: 1
                color: Qt.alpha(Theme.accent, root.hudHovered ? 0.9 : 0.55)

                Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }

        // ── the content row: launcher · island · notifications · settings ──
        Row {
            id: hudRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // ── left: launcher ──
            Item {
                id: utilWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 24 : 0
                height: 24
                opacity: root.utilVisible ? 1 : 0
                x: root.utilVisible ? 0 : -3

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "\u2726"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(16)
                    color: launcherArea.containsMouse ? Theme.accent : Qt.alpha(Theme.fg, 0.62)
                    opacity: launcherArea.containsMouse ? 1 : 0.8

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: launcherArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LauncherState.barAppsOpen = !LauncherState.barAppsOpen
                }
            }

            // ── center: the modes, contained in the one floating panel ──
            DynamicIsland {
                id: island
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── right: bell + settings ──
            Item {
                id: sepWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 10 : 0
                height: 16
                opacity: root.utilVisible ? 1 : 0

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.left: parent.left
                    width: 1; height: 16
                    color: Qt.alpha(Theme.accent, 0.18)
                }
            }

            Item {
                id: notifWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 24 : 0
                height: 24
                opacity: root.utilVisible ? 1 : 0
                x: root.utilVisible ? 0 : 3

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.bell
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(13)
                    color: notifArea.containsMouse ? Theme.accent : Qt.alpha(Theme.fg, 0.62)
                    opacity: notifArea.containsMouse ? 1 : 0.8

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // unread count badge
                Rectangle {
                    visible: Notifier.unreadCount > 0
                    anchors.top: parent.top
                    anchors.topMargin: -1
                    anchors.right: parent.right
                    anchors.rightMargin: -2
                    width: Math.max(14, badgeText.implicitWidth + 6)
                    height: 14
                    radius: 7
                    color: Theme.accent

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: Notifier.unreadCount > 99 ? "99+" : "" + Notifier.unreadCount
                        color: "#fff"
                        font.pixelSize: Theme.fontSize(9)
                        font.family: Theme.fontFamily
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: notifArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (LauncherState.barAppsOpen) LauncherState.barAppsOpen = false;
                        Notifier.markAllRead();
                        Quickshell.execDetached(["bash", "-c", "exec ~/Projects/dots-hyprland/verse/verse toggle notifs"]);
                    }
                }
            }

            Item {
                id: sep2Wrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 10 : 0
                height: 16
                opacity: root.utilVisible ? 1 : 0

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.left: parent.left
                    width: 1; height: 16
                    color: Qt.alpha(Theme.accent, 0.18)
                }
            }

            Item {
                id: settingsWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 24 : 0
                height: 24
                opacity: root.utilVisible ? 1 : 0
                x: root.utilVisible ? 0 : 3

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.settings
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(12)
                    color: settingsArea.containsMouse ? Theme.accent : Qt.alpha(Theme.fg, 0.62)
                    opacity: settingsArea.containsMouse ? 1 : 0.8

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (LauncherState.barAppsOpen) LauncherState.barAppsOpen = false;
                        Quickshell.execDetached(["bash", "-c", "exec ~/Projects/dots-hyprland/verse/verse settings"]);
                    }
                }
            }
        }
    }
}