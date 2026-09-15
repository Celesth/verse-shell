import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/services"

PanelWindow {
    id: root
    anchors {
        top: true
        left: true
        right: true
    }
    property real topMargin: 10 + Settings.barPadding
    margins {
        top: root.topMargin
        left: 18
        right: 18
    }
    implicitHeight: 40
    visible: Settings.barEnabled
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "verse-bar"
    // Keep the optional reservation compact: it is only the 40px bar itself,
    // not the bar plus its floating top margin.
    WlrLayershell.exclusiveZone: Settings.barExclusive ? implicitHeight : 0
    exclusionMode: Settings.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: surface
        anchors.fill: parent
        height: parent.height
        radius: Theme.radius(14)
        color: Settings.glassEffect ? Qt.alpha(Theme.surface, 0.78) : Qt.alpha(Theme.surface, 0.96)
        border.width: 1
        border.color: Qt.alpha(Theme.fg, hover.containsMouse ? 0.20 : 0.12)
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on width { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 10
            WorkspaceIndicator { anchors.verticalCenter: parent.verticalCenter }
            Separator {}
            ActiveWindowTitle { anchors.verticalCenter: parent.verticalCenter }
            Separator {}
            SystemStats { anchors.verticalCenter: parent.verticalCenter }
            Mpris { anchors.verticalCenter: parent.verticalCenter }
            SettingsButton { anchors.verticalCenter: parent.verticalCenter }
        }
    }
    component Separator: Rectangle {
        width: 1; height: 18; radius: 1
        color: Qt.alpha(Theme.fg, 0.12)
    }
}
