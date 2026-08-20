# verse

A Hyprland desktop shell adapted from [pibble](https://github.com/kianblakley/pibble) by Kian Blakley (GPLv3). Includes the shell, a Hyprland config, kitty, fish, starship, and hyprpaper theming.

## Stack

| Component | Role |
|---|---|
| [Quickshell](https://github.com/quickshell-mirror/quickshell) | Shell runtime (QML) |
| [Hyprland](https://github.com/hyprwm/Hyprland) | Wayland compositor |
| [hyprpaper](https://github.com/hyprwm/hyprpaper) | Wallpaper daemon |
| [kitty](https://github.com/kovidgoyal/kitty) | Terminal |
| [fish](https://fishshell.com/) | Shell |
| [starship](https://starship.rs/) | Prompt |
| [dunst](https://dunst-project.org/) | Notification daemon |
| [cliphist](https://github.com/sentriz/cliphist) | Clipboard history |

## Features

- **Launcher** - clock, app drawer, wallpaper selector, clipboard history, power/reboot menus
- **Top bar** - workspaces, clock, active window, system tray (settings toggle)
- **Volume and notification flyouts** - OSDs that pop up over whatever you're doing
- **Weather and battery** - shown on the clock page
- **In-app settings** - appearance, animations, theming, keybindings, layouts, flyouts
- **Custom pages** - drop a QML page into `custom-pages/` and it shows up in the launcher
- **Dynamic theming** - matugen-driven color extraction from your wallpaper, or a custom palette
- **Notification replay** - re-fire recent notifications, stepping back through history
- **Live wallpaper support** - live previews with auto-generated blurred variants
- **Multi-monitor** - the launcher and flyouts follow whichever output is focused
- **Keyboard and gesture navigation** - fully navigable with either alone

## Installation

### 1. Dependencies

| Dependency | Required |
|---|---|
| Hyprland | yes |
| Quickshell | yes |
| hyprpaper | yes |
| kitty | recommended |
| fish + starship | recommended |
| dunst | recommended |
| cliphist | optional (clipboard history) |
| ImageMagick | optional (sharper thumbnails) |
| ffmpeg | optional (video thumbnails) |
| mpvpaper | optional (video wallpapers) |
| matugen | optional (dynamic color theming) |

### 2. Copy configs

```sh
# hyprland config
cp -r hypr/* ~/.config/hypr/

# verse shell (adjust the path in keybinds.conf and autostart.sh)
cp -r verse/ ~/Projects/dots-hyprland/verse/
```

### 3. Adjust paths

Edit `~/.config/hypr/keybinds.conf` and `~/.config/hypr/autostart.sh` to point at wherever you cloned verse.

### 4. Start

Either log out and back in (hyprpaper + verse start via autostart), or:

```sh
~/.config/hypr/autostart.sh
```

## Usage

### `verse` commands

| Command | Description |
|---|---|
| `verse start` | Start the daemon |
| `verse stop` | Stop the daemon |
| `verse restart` | Restart the daemon |
| `verse toggle [page]` | Toggle the launcher; with a page id, open straight to it |
| `verse settings` | Open/toggle settings |
| `verse replay` | Re-fire one recent notification |
| `verse help` | Show usage |

Toggleable pages: `clock`, `apps`, `wallpapers`, `clipboard`, `settings`, plus any custom pages.

### Keybindings

| Action | Key |
|---|---|
| Open launcher | `Super` (hold + release) |
| Clipboard page | `Super+V` |
| Terminal | `Super+Return` |
| File manager | `Super+E` |
| Close window | `Super+Q` |
| Fullscreen | `Super+F` |
| Toggle float | `Super+Space` |
| Screenshot (area) | `Print` |
| Screenshot (screen) | `Shift+Print` |
| Lock | `Super+Escape` |

### In-launcher keybindings

| Action | Key | Gesture |
|---|---|---|
| Cycle pages | `Tab` / `Shift+Tab` | swipe left/right |
| Navigate tiles | arrows / scroll | press |
| Page tiles | `PageUp` / `PageDown` | swipe up/down |
| Activate tile | `Enter` | press |
| Power menu | `Ctrl+P` | swipe down from top edge |
| Reboot menu | `Ctrl+R` | swipe up from bottom edge |
| Settings | `Ctrl+S` | press bottom-right corner |
| Close / go back | `Escape` | right-edge swipe |

## Hyprland config

The `hypr/` directory contains a full Hyprland configuration:

| File | Purpose |
|---|---|
| `hyprland.conf` | Main config (sources all below) |
| `env.conf` | Wayland/Qt environment variables |
| `monitors.conf` | Auto-detect primary monitor |
| `theme.conf` | Colors and animations |
| `keybinds.conf` | All keybinds including verse |
| `windowrules.conf` | Float, opacity, and other rules |
| `autostart.conf` | Startup entries (hyprpaper, verse, dunst, etc.) |
| `autostart.sh` | Autostart script |
| `hyprpaper.conf` | Wallpaper daemon config |

Theme: dark surface (`#0a0908`), warm accent (`#e8a24a`), light fg (`#f3ede4`), 4px gaps, 8px rounding, backdrop blur.

## Wallpaper

Wallpapers are managed through the launcher's wallpaper page (the "walls" pane). The `verse-wallpaper` script handles switching via hyprpaper's config-file approach. Wallpapers are scanned from `~/Pictures/Wallpapers` by default.

## Settings

Open with `Ctrl+S` inside the launcher, or `verse settings` from a terminal. Settings are persisted at:

```
~/.local/state/quickshell/by-shell/<md5-of-shell.qml>/settings.json
```

### Layer-shell namespaces

| Namespace | Window |
|---|---|
| `verse-launcher` | Main launcher |
| `verse-notifications` | Notification flyout |
| `verse-volume` | Volume flyout |
| `verse-bar` | Top bar |

## License

Verse is adapted from [pibble](https://github.com/kianblakley/pibble) by Kian Blakley, licensed under GPLv3.
