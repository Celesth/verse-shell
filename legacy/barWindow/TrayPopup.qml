import QtQuick
import Quickshell
import "root:/config"
import "root:/services"

// A tooltip for a single tray item, shown while the mouse hovers it, anchored
// just below the item. Shows the item's title and, when it has a menu, a hint
// that right-click opens it.
PopupWindow {
    id: root

    color: "transparent"
    grabFocus: false

    property Item anchorItem: null
    property string tipTitle: ""
    property bool tipHasMenu: false
    property bool hovered: false

    // Popups have no native opacity, so we own our own and apply it to the
    // content. Hover-out closes after a tiny delay so the pointer can reach it.
    property bool showInternal: false
    property real opacity: root.showInternal ? 1 : 0

    visible: root.opacity != 0
    onHoveredChanged: hangTimer.restart()

    Timer {
        id: hangTimer
        interval: 60
        onTriggered: root.showInternal = root.hovered
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 120
            easing.type: root.showInternal ? Easing.OutCubic : Easing.InCubic
        }
    }

    width: tooltipRow.implicitWidth + 28
    height: root.tipHasMenu ? 46 : 26

    // Anchor below the item; recomputed each time the popup is shown.
    anchor {
        window: root.anchorItem ? root.anchorItem.QsWindow.window : null
        adjustment: PopupAdjustment.None
        gravity: Edges.Bottom | Edges.Right

        onAnchoring: {
            const pos = root.anchorItem.QsWindow.contentItem.mapFromItem(
                root.anchorItem,
                root.anchorItem.width / 2 - root.width / 2,
                root.anchorItem.height + 6
            );
            anchor.rect.x = pos.x;
            anchor.rect.y = pos.y;
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: root.opacity
        radius: Theme.radius(8)
        color: Theme.surface
        border.color: Qt.alpha(Theme.fg, 0.1)
        border.width: 1

        Column {
            id: tooltipRow
            anchors.centerIn: parent
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.tipTitle
                color: Theme.fg
                font.pixelSize: Theme.fontSize(11)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.tipHasMenu
                text: "right-click for menu"
                color: Qt.alpha(Theme.muted, 0.6)
                font.pixelSize: Theme.fontSize(9)
                font.family: Theme.fontFamily
            }
        }
    }
}
