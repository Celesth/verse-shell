import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "root:/config"
import "root:/launcher"
import "root:/services"
import "root:/ui"

// The bar is a Dynamic Island: a centered pill that floats at the top and
// morphs its width as its center content swaps between modes (see
// DynamicIsland.qml - the window/clock overview, workspaces, system tray, and
// MPRIS, cycled with the mouse wheel). The window surface stays a full-width
// top layer so exclusive-zone, barrier and multi-monitor behaviour are
// untouched - only the drawn pill adapts.
//
// The few always-useful commands live at the pill's sides: the launcher on the
// left, notifications + settings on the right. "Auto-hide bar buttons" folds
// them away unless the pointer is over the island or one of the buttons.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 44
    visible: Settings.barEnabled

    property bool appsOpen: LauncherState.barAppsOpen

    color: "transparent"

    // Liquid glass: when the transparency effect is on the compositor blurs
    // exactly the pill behind it (ext-background-effect-v1). The region follows
    // the pill's geometry - including the animated width - so the blur keeps in
    // step with every morph and never bleeds into the transparent surround.
    BackgroundEffect.blurRegion: Settings.glassEffect ? barGlassRegion : null

    Region {
        id: barGlassRegion
        item: barWrapper
        radius: barWrapper.height / 2
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "verse-bar"
    WlrLayershell.exclusiveZone: Settings.barExclusive ? 38 + Settings.barPadding : 0
    exclusionMode: Settings.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── the pill: centered, its width animate-follows the content ──
    Item {
        id: barWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        height: 36

        // Auto-hidden utilities are width 0 while away but still laid out with
        // the row's spacing, which shows up as extra even padding - symmetric
        // on both sides, so the island stays centered either way.
        readonly property bool utilVisible: !Settings.autoHideButtons || root.utilHovered

        property real targetWidth: Math.min(parent.width - 40, innerRow.implicitWidth + 24)
        width: targetWidth

        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: parent.height / 2
            color: Settings.glassEffect ? Qt.alpha(Theme.surface, 0.55) : Theme.surface
            border.width: Settings.glassEffect ? 1 : 0
            border.color: Settings.glassEffect ? Qt.alpha(Theme.fg, 0.12) : "transparent"

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Settings.glassEffect ? Qt.alpha(Theme.fg, 0.10) : Qt.alpha(Theme.fg, 0.06)
            }
        }

        Row {
            id: innerRow
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
                scale: root.utilVisible ? 1 : 0.9

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: launcherBtn
                    anchors.centerIn: parent
                    width: 24; height: 24
                    radius: height / 2
                    color: launcherArea.containsMouse
                        ? Qt.alpha(Theme.accent, 0.18)
                        : Qt.alpha(Theme.fg, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u2726"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(18)
                        color: Theme.accent
                        opacity: launcherArea.containsMouse ? 1 : 0.75
                    }

                    MouseArea {
                        id: launcherArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LauncherState.barAppsOpen = !LauncherState.barAppsOpen
                    }
                }
            }

            // ── center: the morphing, scroll-cycling island ──
            DynamicIsland {
                id: island
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── right: bell + settings ──
            Item {
                id: sepWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 1 : 0
                height: 14
                opacity: root.utilVisible ? 1 : 0

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 1; height: 14
                    color: Qt.alpha(Theme.muted, 0.2)
                }
            }

            Item {
                id: notifWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 24 : 0
                height: 24
                opacity: root.utilVisible ? 1 : 0
                scale: root.utilVisible ? 1 : 0.9

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: notifBtn
                    anchors.centerIn: parent
                    width: 24; height: 24
                    radius: height / 2
                    color: notifArea.containsMouse
                        ? Qt.alpha(Theme.accent, 0.18)
                        : Qt.alpha(Theme.fg, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.bell
                        font.family: Icons.family
                        font.pixelSize: Theme.fontSize(13)
                        color: Theme.accent
                        opacity: notifArea.containsMouse ? 1 : 0.7
                    }

                    // unread count badge
                    Rectangle {
                        visible: Notifier.unreadCount > 0
                        anchors.top: parent.top
                        anchors.topMargin: -2
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
            }

            Item {
                id: sep2Wrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 1 : 0
                height: 14
                opacity: root.utilVisible ? 1 : 0

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 1; height: 14
                    color: Qt.alpha(Theme.muted, 0.2)
                }
            }

            Item {
                id: settingsWrapper
                anchors.verticalCenter: parent.verticalCenter
                width: root.utilVisible ? 24 : 0
                height: 24
                opacity: root.utilVisible ? 1 : 0
                scale: root.utilVisible ? 1 : 0.9

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: settingsBtn
                    anchors.centerIn: parent
                    width: 24; height: 24
                    radius: height / 2
                    color: settingsArea.containsMouse
                        ? Qt.alpha(Theme.accent, 0.18)
                        : Qt.alpha(Theme.fg, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.settings
                        font.family: Icons.family
                        font.pixelSize: Theme.fontSize(12)
                        color: Theme.accent
                        opacity: settingsArea.containsMouse ? 1 : 0.7
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

    // Revealed while the pointer sits over the island or any of the side
    // buttons. The island owns the only big hover target (its scroller covers
    // the whole center), so that is where the gesture starts from.
    readonly property bool utilHovered: island.hovered
        || launcherArea.containsMouse
        || notifArea.containsMouse
        || settingsArea.containsMouse
}