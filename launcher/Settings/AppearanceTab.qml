import QtQuick
import "root:/launcher"
import "root:/services"
import "root:/ui"

Column {
    id: root

    required property int slideIndex
    required property int activeIndex
    readonly property bool scrambleSuppressed: root.slideIndex !== root.activeIndex

    x: (root.slideIndex - root.activeIndex) * LauncherState.settingsSlideStep
    Behavior on x {
        NumberAnimation { duration: Anim.menu(420); easing.type: Easing.OutCubic }
    }

    spacing: 14

    SettingRow { key: "glassEffect"; label: "Liquid glass"; hint: "transparent surfaces with frosted edges" }
    SettingRow { key: "roundedCorners"; label: "Rounded corners" }
    SettingRow { key: "barEnabled"; label: "Show bar" }
    SettingRow { key: "barExclusive"; label: "Bar reserves space" }
    SettingRow { key: "barPadding"; label: "Bar padding"; hint: "extra gap between bar and windows" }
    SettingRow { key: "hyprBorder"; label: "Window border"; hint: "0 = no borders" }
    SettingRow { key: "hyprRounding"; label: "Window corners"; hint: "0 = no rounding" }
    SettingRow { key: "textScramble"; label: "Text scramble"; hint: "character scramble effect on text" }
    SettingRow { key: "fontFamily"; label: "Font" }
    SettingRow { key: "fontScale"; label: "Font size" }
    ThemeRow {}
    ColorPickerRow {}
}
