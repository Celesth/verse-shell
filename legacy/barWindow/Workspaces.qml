import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

// HUD workspace indicator: a row of numbered slots ("01 02 03 …"). The active
// workspace is bright with a cyan underline, occupied ones get a faint
// underline, empty ones are plain labels. Hovering brightens a slot, clicking
// switches there. Lives in the always-on overview of the floating HUD, so it
// polls the monitor list on its own cadence rather than only while focused.
Item {
    id: root

    implicitWidth: pills.implicitWidth
    implicitHeight: root.slotH

    property int activeId: 1
    property var occupied: []
    // Whether this indicator is usable right now. Gates the hyprctl poll so a
    // monitor that never mounts the HUD doesn't waste the call.
    property bool active: true

    readonly property int count: 10
    readonly property real slotH: 20
    readonly property real slotW: 22
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
        interval: 700
        repeat: true
        running: root.active
        onTriggered: { if (!hyprctl.running) hyprctl.running = true; }
    }
    // one immediate refresh when the HUD comes up, so the indicator doesn't
    // wait up to one poll interval to show current data
    onActiveChanged: {
        if (root.active && !hyprctl.running)
            hyprctl.running = true;
    }

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
                readonly property bool hovered: hoverArea.containsMouse

                readonly property string label: ("" + wsId).padStart(2, "0")

                width: root.slotW
                height: root.slotH

                Text {
                    anchors.centerIn: parent
                    text: parent.label
                    font.pixelSize: Theme.fontSize(9)
                    font.family: Theme.fontFamily
                    font.letterSpacing: 0.5
                    color: parent.isActive
                        ? Theme.fg
                        : (parent.hovered
                            ? Theme.fg
                            : (parent.isOccupied
                                ? Qt.alpha(Theme.muted, 0.95)
                                : Qt.alpha(Theme.muted, 0.55)))
                    opacity: parent.isActive ? 1 : (parent.isOccupied ? 0.9 : 0.7)

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // underline mark: bright accent on the active slot, faint on
                // occupied/hovered, absent on empty ones
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -2
                    width: parent.isActive ? 14 : 8
                    height: 1
                    radius: 0.5
                    color: parent.isActive
                        ? Theme.accent
                        : (parent.isOccupied || parent.hovered)
                            ? Qt.alpha(Theme.accent, 0.4)
                            : "transparent"
                    opacity: parent.isActive ? 1 : 0.6

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(wsId)
                }
            }
        }
    }
}