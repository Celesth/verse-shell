import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 20

    property int activeId: 1

    readonly property int dotSize: 6
    readonly property int gap: 6
    readonly property real pitch: dotSize + gap

    Process {
        id: hyprctl
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.activeId = JSON.parse(text).id; } catch (e) {}
            }
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: { if (!hyprctl.running) hyprctl.running = true; }
        Component.onCompleted: hyprctl.running = true
    }

    function switchTo(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "" + id]);
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Repeater {
            model: 10

            Rectangle {
                required property int index
                property int wsId: index + 1
                property bool isActive: wsId === root.activeId

                x: index * root.pitch
                width: root.dotSize
                height: root.dotSize
                radius: Theme.radius(root.dotSize / 2)
                color: isActive ? Theme.accent : Qt.alpha(Theme.muted, 0.28)

                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(wsId)
                }
            }
        }
    }

    // accent blob that slides between active dots (like pibble's PageDots)
    Rectangle {
        id: blob
        anchors.verticalCenter: parent.verticalCenter
        width: root.dotSize
        height: root.dotSize
        radius: Theme.radius(root.dotSize / 2)
        color: Theme.accent
        x: (root.activeId - 1) * root.pitch

        Behavior on x {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }
}
