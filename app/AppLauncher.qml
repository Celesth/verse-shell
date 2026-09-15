import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/launcher"
import "root:/services"

// A focused application launcher for the Super-key path. It deliberately uses
// the existing DesktopEntries index and LauncherWindow launch signal, so app
// discovery, fuzzy matching and launch-count ranking stay in one place.
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    visible: root.shown
    property bool shown: false
    property string query: ""
    property int selected: 0
    readonly property var matches: Apps.search(query)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "verse-app-launcher"
    WlrLayershell.exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open(): void {
        query = "";
        selected = 0;
        shown = true;
        Qt.callLater(() => search.forceActiveFocus());
    }
    function close(): void { shown = false; }
    function toggle(): void { shown ? close() : open(); }
    function moveSelection(step: int): void {
        if (!matches.length) return;
        selected = (selected + step + matches.length) % matches.length;
        results.positionViewAtIndex(selected, ListView.Contain);
    }
    function launch(entry): void {
        if (!entry) return;
        close();
        LauncherState.launchRequested(entry);
    }
    onMatchesChanged: selected = Math.min(selected, Math.max(0, matches.length - 1))

    // A click outside the compact surface closes it; the launcher itself stays
    // transparent and never needs a costly blur/dim backdrop.
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(620, parent.width - 32)
        height: 404
        radius: Theme.radius(18)
        color: Settings.glassEffect ? Qt.alpha(Theme.surface, 0.90) : Qt.alpha(Theme.surface, 0.98)
        border.width: 1
        border.color: Qt.alpha(Theme.fg, 0.15)

        MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Rectangle {
                width: parent.width
                height: 42
                radius: Theme.radius(11)
                color: Qt.alpha(Theme.fg, 0.06)
                border.width: 1
                border.color: search.activeFocus ? Qt.alpha(Theme.accent, 0.50) : Qt.alpha(Theme.fg, 0.08)
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌕"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(20)
                }
                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 42
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    selectionColor: Qt.alpha(Theme.accent, 0.35)
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.launch(root.matches[root.selected])
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search applications"
                        color: Qt.alpha(Theme.muted, 0.78)
                        font: search.font
                    }
                }
            }

            Text {
                text: root.query ? root.matches.length + " results" : "Applications"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                leftPadding: 4
            }

            ListView {
                id: results
                width: parent.width
                height: parent.height - 42 - 12 - 16 - 12
                clip: true
                spacing: 3
                model: root.matches.length
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property int index
                    readonly property var entry: root.matches[index]
                    readonly property bool current: root.selected === index
                    width: results.width
                    height: 46
                    radius: Theme.radius(10)
                    color: current ? Qt.alpha(Theme.accent, 0.16)
                        : (rowMouse.containsMouse ? Qt.alpha(Theme.fg, 0.07) : "transparent")
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Image {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26
                        source: Icons.url(row.entry?.icon || "")
                        sourceSize: Qt.size(52, 52)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Rectangle {
                        visible: !icon.visible
                        anchors.fill: icon
                        radius: Theme.radius(7)
                        color: Qt.alpha(Theme.accent, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: (row.entry?.name || "?").slice(0, 1).toUpperCase()
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                        }
                    }
                    Text {
                        anchors.left: icon.right
                        anchors.leftMargin: 11
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.entry?.name || ""
                        elide: Text.ElideRight
                        color: row.current ? Theme.fg : Qt.alpha(Theme.fg, 0.82)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = row.index
                        onClicked: root.launch(row.entry)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.matches.length === 0
                    text: "No applications found"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                }
            }
        }
    }
}
