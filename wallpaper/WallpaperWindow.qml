import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "root:/config"
import "root:/services"

// A full-screen, cursor-following wallpaper: the applied wallpaper is zoomed
// in and pans to wherever the pointer is. Enabled by Settings.wallpaperParallax
// (General settings tab). Renders its own wallpaper at the Background layer so
// it sits behind everything - toggle it on instead of the compositor's own (see
// Settings.wallCommand) if you want the effect to be what you see.
//
// Smooth by construction:
//   - the zoomed wallpaper is baked into an offscreen layer texture once
//     (pan.layer.enabled), and cursor moves merely translate that texture
//   - cursor targets come from a low-rate hyprctl poll (no easing on them);
//     a cheap per-frame tick lerps the pane toward that target. That gives
//     fluid motion independent of the poll's own jitter, instead of the old
//     two-chained-Behaviors approach that lagged and stuttered.
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }

    visible: Settings.wallpaperParallax && Wallpapers.matugenSource !== ""

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "verse-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    readonly property real zoomBase: 1.16
    readonly property real panRangeX: root.width * (root.zoomBase - 1)
    readonly property real panRangeY: root.height * (root.zoomBase - 1)

    // raw cursor targets, normalized 0..1 (polled, not eased)
    property real targetX: 0.5
    property real targetY: 0.5
    // current pane offset, eased per frame by the ticker
    property real panX: 0
    property real panY: 0

    Process {
        id: cursorctl
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^\s*(\d+)\s*,\s*(\d+)/.exec(text);
                if (!m) return;
                root.targetX = Math.min(1, Math.max(0, (+m[1]) / Math.max(1, root.width)));
                root.targetY = Math.min(1, Math.max(0, (+m[2]) / Math.max(1, root.height)));
            }
        }
    }

    // low-rate polling of the cursor; the pane is eased by `tick` in between
    Timer {
        id: pollTimer
        interval: 75
        repeat: true
        running: Settings.wallpaperParallax
        onTriggered: { if (!cursorctl.running) cursorctl.running = true; }
        Component.onCompleted: cursorctl.running = true
    }

    // per-frame easing toward the target - cheap (no process, just a lerp),
    // and smooth regardless of the poll's cadence or jitter
    Timer {
        id: tick
        interval: 16
        repeat: true
        running: Settings.wallpaperParallax
        onTriggered: {
            const k = 0.18;
            root.panX += (-root.targetX * root.panRangeX - root.panX) * k;
            root.panY += (-root.targetY * root.panRangeY - root.panY) * k;
        }
    }

    Item {
        id: pan
        width: root.width * root.zoomBase
        height: root.height * root.zoomBase
        layer.enabled: true
        layer.smooth: false

        x: root.panX
        y: root.panY

        Image {
            id: wall
            anchors.fill: parent
            source: Wallpapers.matugenSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    // a gentle top-to-bottom light falloff keeps it from glaring against the
    // bar and launcher text that float over it (static, composited once)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha("#000000", 0.12) }
            GradientStop { position: 1.0; color: Qt.alpha("#000000", 0.04) }
        }
    }
}
