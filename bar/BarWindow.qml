import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "root:/config"
import "root:/launcher"
import "root:/services"
import "root:/ui"

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    height: 44
    visible: Settings.barEnabled

    property bool appsOpen: LauncherState.barAppsOpen

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "verse-bar"
    WlrLayershell.exclusiveZone: Settings.barExclusive ? 38 + Settings.barPadding : 0
    exclusionMode: Settings.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: barWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: parent.width - 40
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, 14)
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

        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            // ── left group ──
            Row {
                id: leftGroup
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
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

            // ── center: active window title ──
            ScrambleText {
                id: activeTitle
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width * 0.35, implicitWidth + 20)
                content: activeWindow.title || ""
                color: Theme.muted
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter
                scrambleSection: "bar"
                followsPane: false
                replayOnChange: true
                opacity: activeWindow.title ? 0.7 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            // ── right group ──
            Row {
                id: rightGroup
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 8

                QsMenuAnchor {
                    id: trayMenuAnchor
                    anchor.window: root.Window.window
                }

                property string timeStr: ""
                property string dateStr: ""

                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    onTriggered: rightGroup.updateTime()
                    Component.onCompleted: rightGroup.updateTime()
                }

                function updateTime() {
                    const now = new Date();
                    timeStr = now.toLocaleTimeString(Qt.locale(), "h:mm AP");
                    dateStr = now.toLocaleDateString(Qt.locale(), "ddd, MMM d, yyyy");
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

                // ── clock (time by default, date on hover) ──
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: clockLabel.implicitWidth + 16
                    height: 28

                    ScrambleText {
                        id: clockLabel
                        anchors.centerIn: parent
                        content: clockHover.containsMouse ? rightGroup.dateStr : rightGroup.timeStr
                        color: Theme.fg
                        font.pixelSize: Theme.fontSize(12)
                        font.family: Theme.fontFamily
                        scrambleSection: "bar"
                        followsPane: false
                        replayOnChange: true

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        id: clockHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const now = new Date();
                            const full = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy");
                            Quickshell.execDetached(["notify-send", "-a", "verse", "-t", "5000", "Calendar", full]);
                        }
                    }
                }

                Rectangle {
                    id: sep3
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

    // ── poll active window ──
    // The active window title is updated reactively via
    // Quickshell.Wayland.ToplevelManager (the `activeWindow` binding on the
    // center label), which the compositor pushes to whenever focus changes.
    // No `hyprctl activewindow` polling needed - spawning a hyprctl subprocess
    // and parsing its JSON every 500ms for the daemon's whole life burned CPU
    // and, worse, the Process's `activeTitle.content = ...` assignment severed
    // that reactive binding, forcing the label to rely on the poll.
}
