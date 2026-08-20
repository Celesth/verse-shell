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
    height: 30
    visible: Settings.barEnabled

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "verse-bar"
    WlrLayershell.exclusiveZone: 26
    exclusionMode: ExclusionMode.Normal

    // pibble-style bar: dark surface, subtle transparency
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.alpha(Theme.surface, 0.88)

        // top accent line
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.accent, 0.3)
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        // left: launcher button
        Rectangle {
            id: launcherBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            radius: Theme.radius(7)
            color: launcherArea.containsMouse
                ? Qt.alpha(Theme.accent, 0.18)
                : Qt.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: launcherArea.containsMouse
                ? Qt.alpha(Theme.accent, 0.4)
                : Qt.alpha(Theme.fg, 0.08)

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: Icons.check
                font.family: Icons.family
                font.pixelSize: Theme.fontSize(12)
                color: Theme.accent
                opacity: launcherArea.containsMouse ? 1 : 0.7
            }

            MouseArea {
                id: launcherArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["bash", "-c", "exec ~/Projects/dots-hyprland/verse/verse toggle"])
            }
        }

        // left: separator
        Rectangle {
            id: sep1
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: launcherBtn.right
            anchors.leftMargin: 8
            width: 1; height: 14
            color: Qt.alpha(Theme.muted, 0.2)
        }

        // left: workspaces
        Workspaces {
            id: workspaces
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: sep1.right
            anchors.leftMargin: 8
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
            anchors.rightMargin: 10
            width: 26; height: 26
            radius: Theme.radius(7)
            color: settingsArea.containsMouse
                ? Qt.alpha(Theme.accent, 0.18)
                : Qt.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: settingsArea.containsMouse
                ? Qt.alpha(Theme.accent, 0.4)
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
                onClicked: Quickshell.execDetached(["bash", "-c", "exec ~/Projects/dots-hyprland/verse/verse settings"])
            }
        }

        // right: separator before clock
        Rectangle {
            id: sep2
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: settingsBtn.left
            anchors.rightMargin: 10
            width: 1; height: 14
            color: Qt.alpha(Theme.muted, 0.2)
        }

        // right: clock
        Clock {
            id: clock
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
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
