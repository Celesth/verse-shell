import QtQuick
import Quickshell.Widgets
import "root:/config"
import "root:/services"
import "root:/ui"

// The wallpaper detail view: grows out of the selected tile (same fly-in as
// ClipExpandCard) and shows the wallpaper under the chosen fit, its metadata,
// and a crop/fit/center fit selector. Single click on a tile or carousel cell
// opens this instead of applying directly; only Apply bakes the display-sized
// copy and runs the wallpaper command. The fit chosen here is both previewed
// and, on Apply, persisted as Settings.wallpaperFit (so it becomes the default
// for wallpaper #4 the way it now is for #1).
Item {
    id: root

    // The pane this grew out of; the collapse animation flies back toward
    // the tile's recorded position in that item's coordinate space.
    required property Item pane

    readonly property var wall: LauncherState.detailWall
    readonly property bool open: wall !== null
    readonly property bool isImg: wall !== null && wall.video !== true

    // The fit being previewed/pending. Seeded from the persisted setting
    // each time the card opens, changed only via the selector, and written
    // back to Settings.wallpaperFit on Apply.
    property string pendingFit: "crop"

    readonly property int fillMode: {
        if (pendingFit === "crop") return Image.PreserveAspectCrop;
        // fit, center and original all show the whole image (the difference is
        // apply-time scaling); center and original simply use the same
        // whole-image view
        return Image.PreserveAspectFit;
    }

    readonly property var infoRows: {
        const w = root.wall;
        if (!w)
            return [];
        const ext = w.path.split(".").pop().toUpperCase();
        const rows = [];
        if (root.nativeRes)
            rows.push(["resolution", root.nativeRes]);
        rows.push(["type", ext]);
        rows.push(["target", Wallpapers.displaySize.width + " x " + Wallpapers.displaySize.height]);
        return rows;
    }

    // Async native resolution (skips video), refilled whenever the card
    // opens on a new wallpaper.
    property string nativeRes: ""
    onWallChanged: {
        nativeRes = "";
        if (wall)
            Wallpapers.probeDimensions(wall, d => { if (wall === LauncherState.detailWall && d) nativeRes = d; });
    }

    anchors.centerIn: parent
    width: 520
    height: column.height + 44
    visible: open && LauncherState.pane === "walls"

    Behavior on height {
        NumberAnimation { duration: Anim.tile(320); easing.type: Easing.OutCubic }
    }
    transform: Translate { id: flyTransform }

    // swallow clicks so they don't fall through to the background (which
    // collapses the card); wheel passes straight through anyway (see
    // ClipExpandCard's note) and there is nothing to scroll here
    MouseArea {
        anchors.fill: parent
    }

    ParallelAnimation {
        id: growAnim
        NumberAnimation { target: flyTransform; property: "x"; to: 0; duration: Anim.tile(400); easing.type: Easing.OutCubic }
        NumberAnimation { target: flyTransform; property: "y"; to: 0; duration: Anim.tile(400); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "opacity"; from: 0.3; to: 1; duration: Anim.tile(240); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.35; to: 1; duration: Anim.tile(400); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }
    SequentialAnimation {
        id: collapseAnim
        ParallelAnimation {
            NumberAnimation { target: flyTransform; property: "x"; to: LauncherState.wallDetailOrigin.x - root.pane.width / 2; duration: Anim.tile(240); easing.type: Easing.InCubic }
            NumberAnimation { target: flyTransform; property: "y"; to: LauncherState.wallDetailOrigin.y - root.pane.height / 2; duration: Anim.tile(240); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "scale"; to: 0.35; duration: Anim.tile(240); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: Anim.tile(240); easing.type: Easing.InCubic }
        }
        ScriptAction { script: LauncherState.detailWall = null }
    }
    Connections {
        target: LauncherState
        function onWallDetailStart() {
            collapseAnim.stop();
            root.pendingFit = Settings.wallpaperFit;
            flyTransform.x = LauncherState.wallDetailOrigin.x - root.pane.width / 2;
            flyTransform.y = LauncherState.wallDetailOrigin.y - root.pane.height / 2;
            growAnim.restart();
        }
        function onWallDetailClose() {
            growAnim.stop();
            collapseAnim.restart();
        }
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 22
        width: parent.width - 48
        spacing: 14

        // The wallpaper itself, shown under the chosen fit. This is the whole
        // point of opening the detail view: the surrounding grid is hidden and
        // the picked wallpaper is displayed large, with its metadata and the
        // crop/fit/center selector below.
        ClippingRectangle {
            id: preview
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: Math.min(parent.width * 0.66, root.pane.height * 0.44)
            radius: Theme.radius(12)
            color: "black"

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: root.isImg ? root.fillMode : Image.PreserveAspectCrop
                // prefer the full-res source; the thumb is the instant
                // placeholder while it lands and the video fallback
                sourceSize: Qt.size(preview.width * 2, preview.height * 2)
                source: {
                    const w = root.wall;
                    if (!w)
                        return "";
                    return "file://" + (w.thumb ? w.thumb : w.path);
                }
            }
        }

        // name line
        Text {
            visible: root.open
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.wall ? LauncherState.wallpaperName(root.wall) : ""
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize(15); weight: Font.DemiBold }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.accent, 0.25)
        }

        Repeater {
            model: root.open ? root.infoRows : []

            Item {
                required property var modelData
                width: column.width
                height: Theme.fontSize(20)

                Text {
                    anchors.left: parent.left
                    text: parent.modelData[0]
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13) }
                }
                Text {
                    anchors.right: parent.right
                    text: parent.modelData[1]
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13) }
                }
            }
        }

        // fit selector
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: [["crop", "Crop"], ["fit", "Fit"], ["center", "Center"], ["original", "Original"]]

                Item {
                    required property var modelData
                    readonly property string fitId: modelData[0]
                    readonly property string fitLabel: modelData[1]
                    width: 110
                    height: 34
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius(9)
                        color: root.pendingFit === parent.fitId ? Qt.alpha(Theme.accent, 0.28) : Qt.alpha(Theme.accent, 0.08)
                        border.width: 1
                        border.color: root.pendingFit === parent.fitId ? Theme.accent : Qt.alpha(Theme.accent, 0.25)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.fitLabel
                        color: root.pendingFit === parent.fitId ? Theme.accent : Theme.fg
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13); weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.pendingFit = parent.fitId
                    }
                }
            }
        }

        // action row: cancel + apply
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Item {
                width: 120
                height: 36
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius(9)
                    color: Qt.alpha(Theme.accent, 0.1)
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.3)
                }
                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13); weight: Font.DemiBold }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: LauncherState.closeWallpaperDetail()
                }
            }
            Item {
                width: 140
                height: 36
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius(9)
                    color: Theme.accent
                }
                Text {
                    anchors.centerIn: parent
                    text: "Apply"
                    color: "#fff"
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13); weight: Font.DemiBold }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Settings.wallpaperFit = root.pendingFit;
                        Settings.save();
                        LauncherState.wallpaperApplyRequested();
                    }
                }
            }
        }
    }
}