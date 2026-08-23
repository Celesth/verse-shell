import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/launcher"
import "root:/services"
import "root:/ui"

PanelWindow {
    id: root

    property bool appsOpen: LauncherState.barAppsOpen

    anchors {
        top: true
        left: true
        right: true
    }
    height: 320
    visible: appsOpen

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "verse-apps"
    WlrLayershell.exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onAppsOpenChanged: {
        if (appsOpen) {
            searchInput.text = "";
            LauncherState.query = "";
            searchInput.forceActiveFocus();
        } else {
            searchInput.text = "";
            LauncherState.query = "";
        }
    }

    // centered panel
    Item {
        id: panelWrapper
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 420)
        height: parent.height - 40

        // background
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Theme.surface

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.alpha(Theme.fg, 0.06)
            }
        }

        // search input — centered at top of panel
        Rectangle {
            id: searchBg
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 32
            height: 30
            radius: 8
            color: Qt.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: searchInput.activeFocus
                ? Qt.alpha(Theme.accent, 0.3)
                : "transparent"

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.pixelSize: Theme.fontSize(12)
                font.family: Theme.fontFamily
                clip: true
                focus: appsOpen
                cursorVisible: appsOpen
                selectionColor: Qt.alpha(Theme.accent, 0.3)
                onTextChanged: LauncherState.query = text
                Keys.onEscapePressed: LauncherState.barAppsOpen = false

                Text {
                    visible: !searchInput.text && !searchInput.activeFocus
                    anchors.centerIn: parent
                    text: "Search apps..."
                    color: Theme.muted
                    font: searchInput.font
                }
            }
        }

        // separator
        Rectangle {
            id: searchSep
            anchors.top: searchBg.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 32
            height: 1
            color: Qt.alpha(Theme.muted, 0.12)
        }

        // scrollable app list with directional fade
        Item {
            id: listClip
            anchors.top: searchSep.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: appColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: appColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        id: appRepeater
                        model: LauncherState.matches

                        Rectangle {
                            id: cell
                            required property int index
                            required property var modelData
                            property var entry: modelData ?? null

                            width: appColumn.width
                            height: 36
                            radius: 10
                            color: cellMouse.containsMouse
                                ? Qt.alpha(Theme.fg, 0.06)
                                : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 28; height: 28; radius: 8
                                    color: Qt.alpha(Theme.accent, 0.12)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: 20; height: 20
                                        source: Icons.url(cell.entry ? cell.entry.icon : "")
                                        sourceSize: Qt.size(40, 40)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !appIcon.visible
                                        text: cell.entry ? cell.entry.name.slice(0, 2).toUpperCase() : ""
                                        color: Theme.accent
                                        font.pixelSize: Theme.fontSize(9)
                                        font.weight: Font.Bold
                                        font.family: Theme.fontFamily
                                    }
                                }

                                ScrambleText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: cell.entry ? cell.entry.name : ""
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize(12)
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    width: appColumn.width - 60
                                    scrambleSection: "bar"
                                    followsPane: false
                                    replayOnChange: true
                                    opacity: cellMouse.containsMouse ? 1 : 0.85
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (cell.entry) {
                                        LauncherState.launchRequested(cell.entry);
                                        LauncherState.barAppsOpen = false;
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: LauncherState.matches.length === 0 && LauncherState.query.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 36
                        verticalAlignment: Text.AlignVCenter
                        text: "No matches"
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize(12)
                        font.family: Theme.fontFamily
                    }
                }
            }

            // top fade mask
            Rectangle {
                id: fadeTop
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 20
                visible: flick.contentY > 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.surface }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // bottom fade mask
            Rectangle {
                id: fadeBottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 20
                visible: flick.contentY < flick.contentHeight - flick.height
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
            }
        }
    }
}
