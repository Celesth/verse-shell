import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "root:/config"
import "root:/launcher"
import "root:/services"
import "root:/ui"

// The bar is a Dynamic Island: a centered pill that floats at the top and
// morphs its width as its center content swaps between the focused window
// (icon + title) and, when nothing is focused, the clock. The window surface
// itself stays a full-width top layer so exclusive-zone, barrier and
// multi-monitor behaviour are untouched - only the drawn pill adapts.
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

            // ── left: launcher, workspaces, now playing ──
            Row {
                id: leftGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // ── launcher button ──
                Rectangle {
                    id: launcherBtn
                    anchors.verticalCenter: parent.verticalCenter
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

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 14
                    color: Qt.alpha(Theme.muted, 0.2)
                }

                // ── workspaces ──
                Workspaces {
                    id: workspaces
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── now playing (MPRIS) ──
                MediaPlayer {
                    id: mediaPlayer
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ── center: the morphing island ──
            DynamicIsland {
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── right: tray, notifications, settings ──
            Row {
                id: rightGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                QsMenuAnchor {
                    id: trayMenuAnchor
                    anchor.window: root.Window.window
                }

                // ── tray icons ──
                Repeater {
                    model: SystemTray.items

                    Item {
                        required property SystemTrayItem modelData

                        width: 22; height: 22

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
                            width: 16; height: 16
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
                            id: trayIconArea
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
                                if (delta !== 0) modelData.scroll(delta, horizontal);
                            }
                        }
                    }
                }

                Rectangle {
                    visible: SystemTray.items.count > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 14
                    color: Qt.alpha(Theme.muted, 0.2)
                }

                // ── notifications bell ──
                Rectangle {
                    id: notifBtn
                    anchors.verticalCenter: parent.verticalCenter
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

                Rectangle {
                    id: sep2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 14
                    color: Qt.alpha(Theme.muted, 0.2)
                }

                // ── settings button ──
                Rectangle {
                    id: settingsBtn
                    anchors.verticalCenter: parent.verticalCenter
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
}