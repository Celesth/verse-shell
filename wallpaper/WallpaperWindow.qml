import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "root:/config"
import "root:/services"

// A full-screen, cursor-following wallpaper: the applied wallpaper is zoomed
// in and its centre pans to wherever the pointer is, so moving the mouse
// glances across the picture. Enabled by Settings.wallpaperParallax (General
// settings tab). Renders its own wallpaper at the Background layer so it sits
// behind everything - toggle it on instead of the compositor's own (see
// Settings.wallCommand) if you want the effect to be what you see.
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }

    visible: Settings.wallpaperParallax && Wallpapers.matugenSource !== ""
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "verse-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // cursor position, normalized 0..1 across this output, eased so the pan
    // glides instead of jumping from poll to poll
    property real cursorX: 0.5
    property real cursorY: 0.5

    readonly property real zoomBase: 1.16

    Process {
        id: cursorctl
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^\s*(\d+)\s*,\s*(\d+)/.exec(text);
                if (!m) return;
                root.cursorX = Math.min(1, Math.max(0, (+m[1]) / Math.max(1, root.width)));
                root.cursorY = Math.min(1, Math.max(0, (+m[2]) / Math.max(1, root.height)));
            }
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: true
        onTriggered: { if (!cursorctl.running) cursorctl.running = true; }
        Component.onCompleted: cursorctl.running = true
    }

    Behavior on cursorX { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on cursorY { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Image {
        id: wall
        anchors.fill: parent
        source: Wallpapers.matugenSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        transform: Scale {
            id: zoom
            xScale: root.zoomBase
            yScale: root.zoomBase
            origin: Qt.point(root.width * root.cursorX, root.height * root.cursorY)
        }

        // a gentle top-to-bottom light falloff keeps it from glaring against
        // the bar and launcher text that float over it
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha("#000000", 0.12) }
                GradientStop { position: 1.0; color: Qt.alpha("#000000", 0.04) }
            }
        }
    }
}
