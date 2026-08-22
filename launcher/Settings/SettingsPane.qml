import QtQuick
import Quickshell
import "root:/config"
import "root:/launcher"
import "root:/services"
import "root:/ui"

Item {
    id: root

    function resetEntrance(): void {
        root.opacity = 0.004;
    }

    property bool scrambleSuppressed: false
    function latchScramble(): void {
        root.scrambleSuppressed = !Settings.hiddenMenuAnimations;
    }
    Component.onCompleted: root.latchScramble()
    readonly property string scrambleSection: "settings"

    readonly property var tabOrder: ["general", "pages", "animations", "keybindings", "flyouts"].concat(LauncherState.customSettingsTabs.map(t => t.pageId))
    readonly property int resolvedTabIndex: tabOrder.indexOf(LauncherState.settingsTab)
    property int tabIndex: 0
    onResolvedTabIndexChanged: if (resolvedTabIndex >= 0)
        tabIndex = resolvedTabIndex

    readonly property real sidebarWidth: 100
    readonly property real pad: 20
    readonly property real maxContentHeight: LauncherState.screenHeight * 0.72

    anchors.centerIn: parent
    width: LauncherState.settingsWidth
    height: root.pad + Math.min(scrollFlick.contentHeight + 4, root.maxContentHeight) + root.pad
    transform: Translate {
        y: LauncherState.powerPull - LauncherState.rebootPull
    }
    opacity: 0.004
    visible: LauncherState.pane === "settings"
    Connections {
        target: LauncherState
        function onPaneChanged() {
            if (LauncherState.pane === "settings") {
                root.latchScramble();
                enterAnim.restart();
                scrollFlick.contentY = 0;
            } else if (Settings.settingsDirty) {
                Settings.savePending();
                Quickshell.execDetached(["notify-send", "-a", "verse", "-i", "preferences-system", "Settings saved", "Changes written to ~/.config/verse/settings.json"]);
            }
        }
    }
    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Anim.menu(200); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.9; to: 1; duration: Anim.menu(500); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        NumberAnimation { target: root; property: "anchors.verticalCenterOffset"; from: 40; to: 0; duration: Anim.menu(500); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius(14)
        color: Qt.alpha(Theme.surface, 0.92)
    }

    // ─── sidebar ───
    Item {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.sidebarWidth

        property var stagedTabs: [
            { id: "general", label: "General", custom: false, phase: "in" },
            { id: "pages", label: "Pages", custom: false, phase: "in" },
            { id: "animations", label: "Animations", custom: false, phase: "in" },
            { id: "keybindings", label: "Navigation", custom: false, phase: "in" },
            { id: "flyouts", label: "Flyouts", custom: false, phase: "in" }
        ]
        function reconcileTabs() {
            const desired = LauncherState.customSettingsTabs;
            const desiredLabel = {};
            for (const t of desired)
                desiredLabel[t.pageId] = t.label;
            const seen = {};
            const next = [];
            for (const t of stagedTabs) {
                if (!t.custom) { next.push(t); continue; }
                seen[t.id] = true;
                if (t.id in desiredLabel)
                    next.push({ id: t.id, label: desiredLabel[t.pageId], custom: true, phase: "in" });
                else if (t.phase === "exiting")
                    next.push(t);
                else {
                    next.push({ id: t.id, label: t.label, custom: true, phase: "exiting" });
                    staleTabSweep.restart();
                }
            }
            for (const t of desired) {
                if (!seen[t.pageId])
                    next.push({ id: t.pageId, label: t.label, custom: true, phase: "entering" });
            }
            stagedTabs = next;
        }
        Component.onCompleted: reconcileTabs()
        Connections {
            target: LauncherState
            function onCustomSettingsTabsChanged() { sidebar.reconcileTabs(); }
        }
        Timer {
            id: staleTabSweep
            interval: Anim.menu(260)
            onTriggered: {
                const next = sidebar.stagedTabs.filter(t => t.phase !== "exiting");
                if (next.length !== sidebar.stagedTabs.length)
                    sidebar.stagedTabs = next;
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: sidebar.stagedTabs

                Rectangle {
                    id: tabBtn
                    required property var modelData
                    required property int index
                    readonly property bool active: LauncherState.settingsTab === modelData.id
                    width: root.sidebarWidth - 16
                    height: 28
                    radius: Theme.radius(8)
                    color: tabBtn.active
                        ? Qt.alpha(Theme.accent, 0.15)
                        : tabBtnArea.containsMouse
                            ? Qt.alpha(Theme.fg, 0.06)
                            : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 14
                        radius: Theme.radius(2)
                        color: Theme.accent
                        opacity: tabBtn.active ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Anim.menu(150); easing.type: Easing.OutCubic }
                        }
                    }

                    ScrambleText {
                        anchors.centerIn: parent
                        height: restHeight
                        content: tabBtn.modelData.label
                        color: tabBtn.active ? Theme.fg : Theme.muted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize(12) }
                    }

                    MouseArea {
                        id: tabBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LauncherState.settingsTab = tabBtn.modelData.id
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.left: sidebar.right
        anchors.top: contentArea.top
        anchors.bottom: contentArea.bottom
        width: 1
        color: Qt.alpha(Theme.muted, 0.15)
    }

    // ─── content area ───
    Item {
        id: contentArea
        anchors.left: sidebar.right
        anchors.leftMargin: 4
        anchors.top: parent.top
        anchors.topMargin: root.pad
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        height: root.height - root.pad * 2
        clip: true

        readonly property real innerWidth: width

        Flickable {
            id: scrollFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: activeCol.height
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            property Item activeCol: col0

            Connections {
                target: root
                function onTabIndexChanged() { scrollFlick.contentY = 0; }
            }

            onActiveColChanged: contentY = 0

            // Tab columns: each positions itself horizontally via x,
            // only the active one is within the viewport.
            Column {
                id: col0
                x: -root.tabIndex * contentArea.innerWidth
                Behavior on x { NumberAnimation { duration: Anim.menu(420); easing.type: Easing.OutCubic } }
                visible: x > -contentArea.innerWidth * 1.5 && x < contentArea.innerWidth * 1.5
                width: contentArea.innerWidth
                spacing: 14
                GeneralTab { width: parent.width; slideIndex: 0; activeIndex: root.tabIndex; x: 0 }
            }
            Column {
                id: col1
                x: (1 - root.tabIndex) * contentArea.innerWidth
                Behavior on x { NumberAnimation { duration: Anim.menu(420); easing.type: Easing.OutCubic } }
                visible: x > -contentArea.innerWidth * 1.5 && x < contentArea.innerWidth * 1.5
                width: contentArea.innerWidth
                spacing: 14
                PagesTab { width: parent.width; slideIndex: 1; activeIndex: root.tabIndex; x: 0 }
            }
            Column {
                id: col2
                x: (2 - root.tabIndex) * contentArea.innerWidth
                Behavior on x { NumberAnimation { duration: Anim.menu(420); easing.type: Easing.OutCubic } }
                visible: x > -contentArea.innerWidth * 1.5 && x < contentArea.innerWidth * 1.5
                width: contentArea.innerWidth
                spacing: 14
                AnimationsTab { width: parent.width; slideIndex: 2; activeIndex: root.tabIndex; x: 0 }
            }
            Column {
                id: col3
                x: (3 - root.tabIndex) * contentArea.innerWidth
                Behavior on x { NumberAnimation { duration: Anim.menu(420); easing.type: Easing.OutCubic } }
                visible: x > -contentArea.innerWidth * 1.5 && x < contentArea.innerWidth * 1.5
                width: contentArea.innerWidth
                spacing: 14
                NavigationTab { width: parent.width; slideIndex: 3; activeIndex: root.tabIndex; x: 0 }
            }
            Column {
                id: col4
                x: (4 - root.tabIndex) * contentArea.innerWidth
                Behavior on x { NumberAnimation { duration: Anim.menu(420); easing.type: Easing.OutCubic } }
                visible: x > -contentArea.innerWidth * 1.5 && x < contentArea.innerWidth * 1.5
                width: contentArea.innerWidth
                spacing: 14
                FlyoutsTab { width: parent.width; slideIndex: 4; activeIndex: root.tabIndex; x: 0 }
            }
            Repeater {
                id: customCols
                model: LauncherState.customSettingsTabs
                Column {
                    required property var modelData
                    readonly property int slideIndex: root.tabOrder.indexOf(modelData.pageId)
                    x: (slideIndex - root.tabIndex) * contentArea.innerWidth
                    visible: x > -contentArea.innerWidth * 1.5 && x < contentArea.innerWidth * 1.5
                    width: contentArea.innerWidth
                    spacing: 14
                    Loader { sourceComponent: modelData.component }
                }
            }
        }

        // set activeCol when tab changes
        Connections {
            target: root
            function onTabIndexChanged() {
                switch (root.tabIndex) {
                case 0: scrollFlick.activeCol = col0; break;
                case 1: scrollFlick.activeCol = col1; break;
                case 2: scrollFlick.activeCol = col2; break;
                case 3: scrollFlick.activeCol = col3; break;
                case 4: scrollFlick.activeCol = col4; break;
                default: scrollFlick.activeCol = col0; break;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onPressed: mouse => {
            if (LauncherState.capturingBind)
                LauncherState.cancelCapture();
            mouse.accepted = false;
        }
    }
}
