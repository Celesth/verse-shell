import QtQuick
import Quickshell.Hyprland
import "root:/config"
import "root:/services"

Item {
    id: root
    implicitWidth: 250
    implicitHeight: 28
    readonly property var window: Hyprland.activeWindow
    readonly property string title: (window?.title || "").trim()
    readonly property string appClass: (window?.class || "").trim()
    readonly property string displayTitle: title || appClass || "Desktop"

    Text {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        text: root.displayTitle
        elide: Text.ElideRight
        maximumLineCount: 1
        color: Qt.alpha(Theme.fg, 0.90)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(11)
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
}
