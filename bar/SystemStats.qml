import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

Item {
    id: root
    implicitWidth: stats.implicitWidth
    implicitHeight: 28
    property int cpu: 0
    property int memory: 0

    Process {
        id: cpuProcess
        command: ["sh", Quickshell.shellDir + "/scripts/cpu_usage.sh"]
        stdout: StdioCollector { onStreamFinished: root.cpu = Number(text.trim()) || 0 }
    }
    Process {
        id: memoryProcess
        command: ["sh", Quickshell.shellDir + "/scripts/memory_usage.sh"]
        stdout: StdioCollector { onStreamFinished: root.memory = Number(text.trim()) || 0 }
    }
    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProcess.running) cpuProcess.running = true;
            if (!memoryProcess.running) memoryProcess.running = true;
        }
    }

    Row {
        id: stats
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Stat { icon: "CPU"; value: root.cpu + "%" }
        Stat { icon: "RAM"; value: root.memory + "%" }
    }

    component Stat: Item {
        required property string icon
        required property string value
        implicitWidth: label.implicitWidth + 12
        implicitHeight: 24
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius(7)
            color: mouse.containsMouse ? Qt.alpha(Theme.fg, 0.07) : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
        }
        Text {
            id: label
            anchors.centerIn: parent
            text: parent.icon + " " + parent.value
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(9)
            color: Qt.alpha(Theme.fg, 0.74)
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true }
    }
}
