import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/config"
import "root:/services"

// The morphing heart of the bar. One persistent pill whose *content* swaps
// between two states and whose *width* follows whichever is showing:
//
//   focused window  →  [icon] title (elided, clamped)
//   nothing focused →  clock (dd MMM • H:mm, full date on hover)
//
// Focus is tracked reactively from Quickshell.Hyprland.activeWindow - no IPC
// polling; the compositor event arrives, the bindings re-evaluate, and only
// the layers that own the change animate. The clock updates once a minute
// (30s timer bounded staleness) and animates nothing while time simply ticks.
Item {
    id: root

    implicitHeight: 28
    height: 28

    // ── state source: the single place focus → display is decided ──
    readonly property var activeWin: Hyprland.activeWindow
    readonly property string rawTitle: activeWin?.title ?? ""
    readonly property string winClass: activeWin?.class ?? ""
    readonly property url winIcon: activeWin?.icon ?? ""
    // A useable title, else the window class, else nothing - and "nothing"
    // means the island drops to the clock state rather than ever showing
    // undefined/null/empty text.
    readonly property string displayTitle: {
        const t = (rawTitle || "").trim();
        if (t !== "") return t;
        const c = (winClass || "").trim();
        return c !== "" ? c : "";
    }
    readonly property bool hasWindow: displayTitle !== ""

    // ── geometry: width tracks whichever layer is on, clamped ──
    readonly property real minW: 176
    readonly property real maxW: 440
    readonly property real padX: 20
    readonly property real iconW: 16
    readonly property real titleMax: Math.max(maxW - padX - iconW - 8 - 40, 80)

    width: Math.min(maxW, Math.max(minW,
        (hasWindow ? windowContent.implicitWidth : clockContent.implicitWidth) + padX))

    clip: true

    // ── window state: icon + elided title, slides out to the left ──
    Item {
        id: windowLayer
        width: parent.width
        height: parent.height

        opacity: root.hasWindow ? 1 : 0
        x: root.hasWindow ? 0 : -18

        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Row {
            id: windowContent
            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconW
                height: root.iconW
                source: root.winIcon
                sourceSize.width: root.iconW * 2
                sourceSize.height: root.iconW * 2
                fillMode: Image.PreserveAspectFit
                visible: root.winIcon.toString() !== ""
                smooth: false
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayTitle
                color: Theme.fg
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, root.titleMax)
            }
        }
    }

    // ── clock state: slides in from the right, calendar on hover ──
    Item {
        id: clockLayer
        width: parent.width
        height: parent.height
        enabled: !root.hasWindow

        opacity: root.hasWindow ? 0 : 1
        x: root.hasWindow ? 18 : 0

        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Row {
            id: clockContent
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\ue425"
                font.family: Icons.family
                font.pixelSize: Theme.fontSize(11)
                color: Qt.alpha(Theme.muted, 0.7)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clockHover.containsMouse ? root.fullDate : (root.dateStr + " • " + root.timeStr)
                color: Theme.fg
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
            }
        }

        MouseArea {
            id: clockHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["notify-send", "-a", "verse", "-t", "5000", "Calendar", root.fullDate]);
            }
        }
    }

    // ── clock data: once a minute is plenty for a minutes-only clock ──
    property string timeStr: ""
    property string dateStr: ""
    property string fullDate: ""

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.updateTime()
        Component.onCompleted: root.updateTime()
    }

    function updateTime() {
        const now = new Date();
        timeStr = now.toLocaleTimeString(Qt.locale(), "H:mm");
        dateStr = now.toLocaleDateString(Qt.locale(), "d MMM");
        fullDate = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy");
    }
}