import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

// Workspace indicator: a row of numbered pill segments. The active workspace
// lights up in the accent colour with a bold number; occupied workspaces show
// a dimmer filled pill, empty ones a hollow pill. Hovering a segment tint it
// and clicking switches there.
Item {
    id: root

    implicitWidth: pills.implicitWidth
    implicitHeight: root.pillH

    property int activeId: 1
    property var occupied: []
    // Whether this indicator is usable right now. Gates the hyprctl poll below
    // so an island that hides the workspace mode doesn't run it at all: the
    // 350ms monitors call is only ever spent while the user is looking at it.
    property bool active: false

    readonly property int count: 10
    readonly property real pillH: 22
    readonly property real pillW: 24
    readonly property real gap: 3

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
        running: root.active
        onTriggered: { if (!hyprctl.running) hyprctl.running = true; }
    }
    // one immediate refresh when the workspace mode comes into view, so the
    // indicator doesn't wait up to one poll interval to show current data
    onActiveChanged: {
        if (root.active && !hyprctl.running)
            hyprctl.running = true;
    }

    readonly property var jpNumerals: ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    function switchTo(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "" + id]);
    }

    Row {
        id: pills
        spacing: root.gap

        Repeater {
            model: root.count

            Item {
                required property int index

                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property bool isOccupied: root.occupied.indexOf(wsId) !== -1
                readonly property bool hovered: hover.containsMouse

                width: root.pillW
                height: root.pillH

                Rectangle {
                    anchors.centerIn: parent
                    width: root.pillW
                    height: root.pillH
                    radius: Theme.radius(root.pillH / 4)
                    color: isActive
                        ? Theme.accent
                        : (isOccupied
                            ? Qt.alpha(Theme.fg, hovered ? 0.32 : 0.22)
                            : (hovered ? "transparent" : "transparent"))
                    border.width: (isActive || isOccupied) ? 0 : 1
                    border.color: hovered
                        ? Qt.alpha(Theme.fg, 0.5)
                        : Qt.alpha(Theme.fg, 0.28)

                    Text {
                        anchors.centerIn: parent
                        text: root.jpNumerals[wsId] ?? ""
                        font.pixelSize: Theme.fontSize(11)
                        font.bold: isActive
                        font.family: Theme.fontFamily
                        color: isActive
                            ? Theme.fg
                            : (hovered ? Theme.fg : Qt.alpha(Theme.fg, 0.72))
                        opacity: isActive ? 1 : (isOccupied ? 0.95 : 0.8)
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(wsId)
                }
            }
        }
    }
}
