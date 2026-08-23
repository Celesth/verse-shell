import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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
        width: Math.min(parent.width - 40, 900)
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, 14)
            color: Theme.surface

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.alpha(Theme.fg, 0.06)
            }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14

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
                    text: "A"
                    font.pixelSize: Theme.fontSize(12)
                    font.weight: Font.Bold
                    color: Theme.accent
                    opacity: launcherArea.containsMouse ? 1 : 0.7
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
                id: sep1
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: launcherBtn.right
                anchors.leftMargin: 8
                width: 1; height: 14
                color: Qt.alpha(Theme.muted, 0.2)
            }

            // ── workspaces ──
            Workspaces {
                id: workspaces
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: sep1.right
                anchors.leftMargin: 8
            }

            // ── center: active window title ──
            ScrambleText {
                id: activeTitle
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width * 0.4, implicitWidth + 20)
                content: activeWindow.title || ""
                color: Theme.muted
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                maximumLineCount: 1
                scrambleSection: "bar"
                followsPane: false
                replayOnChange: true
                opacity: activeWindow.title ? 0.7 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            // ── right group ──

            Item {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: sep2.left
                anchors.rightMargin: 8
                implicitWidth: clockRow.implicitWidth
                implicitHeight: 20

                property string timeStr: ""
                property string dateStr: ""

                Row {
                    id: clockRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\ue425"
                        font.family: Icons.family
                        font.pixelSize: Theme.fontSize(10)
                        color: Qt.alpha(Theme.muted, 0.6)
                    }

                    ScrambleText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: clock.timeStr
                        color: Theme.fg
                        font.pixelSize: Theme.fontSize(12)
                        font.family: Theme.fontFamily
                        scrambleSection: "bar"
                        followsPane: false
                        replayOnChange: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u00b7"
                        color: Qt.alpha(Theme.muted, 0.4)
                        font.pixelSize: Theme.fontSize(12)
                        font.family: Theme.fontFamily
                    }

                    ScrambleText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: clock.dateStr
                        color: Qt.alpha(Theme.muted, 0.7)
                        font.pixelSize: Theme.fontSize(11)
                        font.family: Theme.fontFamily
                        scrambleSection: "bar"
                        followsPane: false
                        replayOnChange: true
                    }
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    onTriggered: clock.updateTime()
                    Component.onCompleted: clock.updateTime()
                }

                function updateTime() {
                    const now = new Date();
                    timeStr = now.toLocaleTimeString(Qt.locale(), "h:mm AP");
                    dateStr = now.toLocaleDateString(Qt.locale(), "ddd, MMM d, yyyy");
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const now = new Date();
                        const full = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy");
                        Quickshell.execDetached(["notify-send", "-a", "verse", "-t", "5000", "Calendar", full]);
                    }
                }
            }

            Rectangle {
                id: sep2
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: settingsBtn.left
                anchors.rightMargin: 8
                width: 1; height: 14
                color: Qt.alpha(Theme.muted, 0.2)
            }

            Rectangle {
                id: settingsBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
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

    // ── poll active window ──
    Process {
        id: windowPoll
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    activeTitle.content = d.title || "";
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: { if (!windowPoll.running) windowPoll.running = true; }
        Component.onCompleted: windowPoll.running = true
    }
}
