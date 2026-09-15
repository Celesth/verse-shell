import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 26
    property int activeId: 1
    property var occupied: []

    Process {
        id: hyprctl
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const monitors = JSON.parse(text);
                    const used = [];
                    for (const monitor of monitors) {
                        for (const workspace of (monitor.workspaces || []))
                            used.push(workspace.id);
                        if (monitor.focused && monitor.activeWorkspace)
                            root.activeId = monitor.activeWorkspace.id;
                    }
                    root.occupied = used;
                } catch (error) {}
            }
        }
    }

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!hyprctl.running) hyprctl.running = true; }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: 10

            Item {
                required property int index
                readonly property int workspaceId: index + 1
                readonly property bool selected: workspaceId === root.activeId
                readonly property bool used: root.occupied.indexOf(workspaceId) >= 0
                width: 24; height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius(7)
                    color: parent.selected ? Qt.alpha(Theme.accent, 0.20)
                        : (mouse.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: ("0" + parent.workspaceId).slice(-2)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(9)
                    font.weight: parent.selected ? Font.DemiBold : Font.Normal
                    color: parent.selected ? Theme.accent
                        : (parent.used ? Qt.alpha(Theme.fg, 0.72) : Qt.alpha(Theme.muted, 0.55))
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "" + parent.workspaceId])
                }
            }
        }
    }
}
