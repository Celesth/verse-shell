import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

// A unique per-workspace indicator: a row of diamond "gems" sitting on a thin
// recessed rail. The active workspace is a solid accent gem, occupied ones are
// tinted with an accent edge, and empty slots are just hollow outlines - so
// what's busy and what's focused reads at a glance.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 20

    property int activeId: 1
    property var occupied: []

    readonly property int cell: 14
    readonly property int idleGem: 7
    readonly property int activeGem: 11
    readonly property int gap: 4

    Process {
        id: hyprctl
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const monitors = JSON.parse(text);
                    const occ = [];
                    for (const monitor of monitors) {
                        for (const ws of (monitor.workspaces || []))
                            occ.push(ws.id);
                        if (monitor.focused && monitor.activeWorkspace)
                            root.activeId = monitor.activeWorkspace.id;
                    }
                    root.occupied = occ;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 350
        repeat: true
        running: true
        onTriggered: { if (!hyprctl.running) hyprctl.running = true; }
        Component.onCompleted: hyprctl.running = true
    }

    function switchTo(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "" + id]);
    }

    // thin recessed rail behind the gems
    Rectangle {
        id: rail
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: row.implicitWidth
        height: 3
        radius: Theme.radius(1.5)
        color: Qt.alpha(Theme.muted, 0.14)
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Repeater {
            model: 10

            // each slot: a rotating square (diamond) that fills when focused
            Item {
                required property int index

                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property bool isOccupied: root.occupied.indexOf(wsId) !== -1

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors.centerIn: parent
                    rotation: 45

                    width: parent.isActive ? root.activeGem : root.idleGem
                    height: width
                    radius: 2

                    color: parent.isActive
                        ? Theme.accent
                        : (parent.isOccupied ? Qt.alpha(Theme.accent, 0.4) : "transparent")

                    border.color: parent.isActive
                        ? Qt.lighter(Theme.accent, 1.2)
                        : (parent.isOccupied
                            ? Qt.alpha(Theme.accent, 0.75)
                            : Qt.alpha(Theme.muted, 0.5))
                    border.width: parent.isActive ? 0 : 1

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchTo(parent.parent.wsId)
                    }
                }
            }
        }
    }
}
