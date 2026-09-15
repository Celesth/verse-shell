import QtQuick
import Quickshell
import "root:/config"
import "root:/services"

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 28
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius(8)
        color: mouse.containsMouse ? Qt.alpha(Theme.accent, 0.16) : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }
    Text {
        anchors.centerIn: parent
        text: Icons.settings
        font.family: Icons.family
        font.pixelSize: Theme.fontSize(14)
        color: mouse.containsMouse ? Theme.accent : Qt.alpha(Theme.fg, 0.72)
        Behavior on color { ColorAnimation { duration: 130 } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", "-c", "exec \"$1/verse\" settings", "_", Quickshell.shellDir])
    }
}
