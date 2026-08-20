import QtQuick
import Quickshell
import "root:/config"
import "root:/services"

Item {
    id: root

    implicitWidth: clockRow.implicitWidth
    implicitHeight: 20

    property string timeStr: ""
    property string dateStr: ""

    Row {
        id: clockRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // clock icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\ue425"
            font.family: Icons.family
            font.pixelSize: Theme.fontSize(11)
            color: Qt.alpha(Theme.muted, 0.6)
        }

        // time
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeStr
            color: Theme.fg
            font.pixelSize: Theme.fontSize(13)
            font.family: Theme.fontFamily
        }

        // date
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateStr
            color: Qt.alpha(Theme.muted, 0.7)
            font.pixelSize: Theme.fontSize(11)
            font.family: Theme.fontFamily
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.updateTime()
        Component.onCompleted: updateTime()
    }

    function updateTime() {
        const now = new Date();
        timeStr = now.toLocaleTimeString(Qt.locale(), "HH:mm");
        dateStr = now.toLocaleDateString(Qt.locale(), "ddd MMM d");
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
