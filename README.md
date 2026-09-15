# verse

A Hyprland desktop shell built on [Quickshell](https://github.com/quickshell-mirror/quickshell), adapted from [pibble](https://github.com/kianblakley/pibble) (GPLv3).

## Quick start

```sh
verse start
```

Or log out and back in — verse starts via autostart (wallpapers are rendered by awww).

## Usage

```
verse start              # start daemon
verse stop               # stop daemon
verse restart            # restart daemon
verse toggle [page]      # toggle launcher (+ optional page)
verse settings           # open settings
verse replay             # re-fire recent notification
verse help               # show help
```

## Pages

`clock` · `apps` · `wallpapers` · `clipboard` · `media` · `settings` · custom pages via `custom-pages/`

## Keybindings

| Action | Key |
|---|---|
| Open launcher | `Super` |
| Terminal | `Super+Return` |
| Clipboard | `Super+V` |
| Close window | `Super+Q` |
| Fullscreen | `Super+F` |
| Float | `Super+Space` |
| Screenshot (area) | `Print` |
| Screenshot (screen) | `Shift+Print` |
| Settings (in launcher) | `Ctrl+S` |
| Cycle pages | `Tab` / `Shift+Tab` |
| Close / go back | `Escape` |

## Settings

Open with `Ctrl+S` inside the launcher or `verse settings` from a terminal.

## License

GPLv3 — adapted from [pibble](https://github.com/kianblakley/pibble) by Kian Blakley.
