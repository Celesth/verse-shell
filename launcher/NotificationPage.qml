import QtQuick
import Quickshell.Widgets
import "root:/config"
import "root:/services"
import "root:/ui"

// The notification center: a vertical list of incoming notifications, most
// recent first, with app icons, truncated bodies, per-row copy + delete
// buttons, and a clear-all action. Opens like the clipboard page — staggered
// spring-in on pane enter.
Item {
    id: root

    anchors.fill: parent

    function resetEntrance(): void {
        drawer.opacity = 0.004;
    }

    Item {
        id: drawer
        anchors.centerIn: parent
        readonly property int queryH: Settings.pageIndicatorEnabled("query") ? 32 : 0
        readonly property int dotsH: Settings.pageIndicatorEnabled("dots") ? 20 : 0
        width: 480
        height: Math.max(listView.contentHeight + 48, 120) + drawer.queryH + drawer.dotsH
        Behavior on height {
            NumberAnimation { duration: Anim.tile(240); easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: LauncherState.powerPull - LauncherState.rebootPull
        }
        opacity: 0.004
        visible: LauncherState.pane === "notifs"
        Connections {
            target: LauncherState
            function onPaneChanged() {
                if (LauncherState.pane === "notifs") {
                    enterAnim.restart();
                    Notifier.markAllRead();
                }
            }
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: drawer; property: "opacity"; from: 0; to: 1; duration: Anim.tile(200); easing.type: Easing.OutCubic }
            NumberAnimation { target: drawer; property: "scale"; from: 0.9; to: 1; duration: Anim.tile(500); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            NumberAnimation { target: drawer; property: "anchors.verticalCenterOffset"; from: 40; to: 0; duration: Anim.tile(500); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        }

        PageQueryLabel {
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            queryText: LauncherState.query
        }

        // ── header: clear all ──
        // Small trash-action top-right, sitting in the same strip as the query
        // label. Only shows while there is anything to clear.
        Rectangle {
            id: clearAll
            visible: Notifier.history.length > 0
            anchors.top: parent.top
            anchors.topMargin: 2
            anchors.right: parent.right
            anchors.rightMargin: 24
            width: 90
            height: 24
            radius: Theme.radius(8)
            color: clearAllHover.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.accent, 0.08)
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.trash
                font.family: Icons.family
                font.pixelSize: Theme.fontSize(12)
                color: Theme.accent
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                text: "clear all"
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize(11) }
            }
            MouseArea {
                id: clearAllHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifier.clearHistory()
            }
        }

        // ── notification list ──
        ListView {
            id: listView
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 26 + drawer.queryH
            width: 432
            height: Math.min(contentHeight, root.height - 80 - drawer.queryH - drawer.dotsH)
            clip: true
            spacing: 8
            model: Notifier.history

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: listView.width
                height: 56
                opacity: 0
                scale: Anim.fromScale

                Component.onCompleted: {
                    cellSpringIn.restart();
                }

                SequentialAnimation {
                    id: cellSpringIn
                    PauseAnimation { duration: Anim.stagger(cell.index, 1, 40) }
                    ParallelAnimation {
                        NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Anim.fadeDuration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: cell; property: "scale"; to: 1; duration: Anim.duration; easing.type: Anim.easing; easing.overshoot: 2.2 }
                    }
                }

                // card background (tints on row hover)
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius(12)
                    color: cellHover.containsMouse ? Qt.alpha(Theme.accent, 0.12) : Qt.alpha(Theme.accent, 0.06)
                    border.width: 1
                    border.color: cellHover.containsMouse ? Qt.alpha(Theme.accent, 0.25) : Qt.alpha(Theme.accent, 0.1)

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                // row hover detection. Declared before the buttons so they stay
                // on top and keep receiving their own clicks.
                MouseArea {
                    id: cellHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                // app icon (tinted circle)
                Rectangle {
                    id: iconBg
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32
                    radius: 8
                    color: Qt.alpha(Theme.accent, 0.15)

                    Image {
                        id: iconImg
                        anchors.fill: parent
                        anchors.margins: 4
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        source: {
                            const ic = cell.modelData.icon;
                            if (!ic)
                                return "";
                            if (ic.startsWith("image://") || ic.startsWith("file://"))
                                return ic;
                            return "file://" + ic;
                        }
                        visible: status === Image.Ready
                    }
                    // fallback: glyph from Notifier.glyphFor
                    Text {
                        anchors.centerIn: parent
                        visible: iconImg.status !== Image.Ready
                        text: cell.modelData.glyph || Icons.bell
                        font.family: Icons.family
                        font.pixelSize: Theme.fontSize(14)
                        color: Theme.accent
                    }
                }

                // summary
                Text {
                    anchors.left: iconBg.right
                    anchors.leftMargin: 10
                    anchors.right: actions.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -8
                    text: cell.modelData.summary || ""
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(13); weight: Font.DemiBold }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // body (truncated)
                Text {
                    anchors.left: iconBg.right
                    anchors.leftMargin: 10
                    anchors.right: actions.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 10
                    text: cell.modelData.body || ""
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(11) }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text !== ""
                }

                // timestamp
                Text {
                    anchors.right: actions.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -8
                    text: Format.timeAgo(cell.modelData.timestamp)
                    color: Qt.alpha(Theme.muted, 0.6)
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize(10) }
                }

                // ── row actions: copy + delete ──
                // Two small icon buttons on the right. Copy is silent (no
                // toast); delete drops the entry from the on-disk history.
                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 24; height: 24
                        radius: 6
                        color: copyBtn.containsMouse ? Qt.alpha(Theme.accent, 0.22) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: Icons.copy
                            font.family: Icons.family
                            font.pixelSize: Theme.fontSize(14)
                            color: copyBtn.containsMouse ? Theme.fg : Theme.muted
                        }
                        MouseArea {
                            id: copyBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifier.copySilent(cell.modelData.summary + (cell.modelData.body ? "\n" + cell.modelData.body : ""))
                        }
                    }

                    Rectangle {
                        width: 24; height: 24
                        radius: 6
                        color: delBtn.containsMouse ? Qt.alpha(Theme.accent, 0.22) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: Icons.trash
                            font.family: Icons.family
                            font.pixelSize: Theme.fontSize(14)
                            color: delBtn.containsMouse ? Theme.fg : Theme.muted
                        }
                        MouseArea {
                            id: delBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifier.removeFromHistory(cell.modelData)
                        }
                    }
                }
            }
        }

        // empty state
        ScrambleText {
            visible: LauncherState.pane === "notifs" && Notifier.history.length === 0
            anchors.centerIn: parent
            transform: Translate {
                y: LauncherState.powerPull - LauncherState.rebootPull
            }
            width: restWidth
            height: restHeight
            content: "no notifications"
            color: Theme.muted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize(14) }
        }

        PageDots {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            pageCount: 1
            currentPage: 0
            visible: false
        }
    }
}