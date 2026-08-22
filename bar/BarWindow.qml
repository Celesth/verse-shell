import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "root:/config"
import "root:/services"

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    height: 44
    visible: Settings.barEnabled

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "verse-bar"
    WlrLayershell.exclusiveZone: Settings.barExclusive ? 38 + Settings.barPadding : 0
    exclusionMode: Settings.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore

    // floating bar container — centered, with margin from top edge
    Item {
        id: barWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: Math.min(parent.width - 40, 900)
        height: root.height - 8

        // solid curved background
        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, 14)
            color: Theme.surface

            // subtle top highlight
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

        // content row
        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // left: launcher button (Arch icon)
            Rectangle {
                id: launcherBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28
                radius: height / 2
                color: launcherArea.containsMouse
                    ? Qt.alpha(Theme.accent, 0.18)
                    : Qt.alpha(Theme.fg, 0.08)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "A"
                    font.pixelSize: Theme.fontSize(14)
                    font.weight: Font.Bold
                    color: Theme.accent
                    opacity: launcherArea.containsMouse ? 1 : 0.7
                }

                MouseArea {
                    id: launcherArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", "-c", "exec ~/Projects/dots-hyprland/verse/verse toggle apps"])
                }
            }

            // left: separator
            Rectangle {
                id: sep1
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: launcherBtn.right
                anchors.leftMargin: 10
                width: 1; height: 16
                color: Qt.alpha(Theme.muted, 0.2)
            }

            // left: workspaces
            Workspaces {
                id: workspaces
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: sep1.right
                anchors.leftMargin: 10
            }

            // center: active window title
            ActiveWindow {
                id: activeWindow
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width * 0.4, implicitWidth + 20)
            }

            // right: settings button
            Rectangle {
                id: settingsBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: clock.left
                anchors.rightMargin: 12
                width: 28; height: 28
                radius: height / 2
                color: settingsArea.containsMouse
                    ? Qt.alpha(Theme.accent, 0.18)
                    : Qt.alpha(Theme.fg, 0.08)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.settings
                    font.family: Icons.family
                    font.pixelSize: Theme.fontSize(13)
                    color: Theme.accent
                    opacity: settingsArea.containsMouse ? 1 : 0.7
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", "-c", "exec ~/Projects/dots-hyprland/verse/verse settings"])
                }
            }

            // right: separator before clock
            Rectangle {
                id: sep2
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: settingsBtn.left
                anchors.rightMargin: 12
                width: 1; height: 16
                color: Qt.alpha(Theme.muted, 0.2)
            }

            // right: clock
            Clock {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
            }
        }
    }

    // poll active window
    Process {
        id: windowPoll
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    activeWindow.title = d.title || "";
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
