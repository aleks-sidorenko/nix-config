# apps/

Applications a user runs.

| Sub-directory | Features (from `master`) |
|---|---|
| `browsers/` | `chrome`, `chromium`, `firefox`, `default-browser` |
| `communication/` | `slack`, `telegram`, `viber`, `zoom` |
| `media/` | `vlc`, `shotwell`, `lightroom`, `qbittorrent-client`, `media-tools`, `default-player` |
| `productivity/` | `libreoffice`, `default-office` |
| `games/` | `minecraft` |

Examples:
- `darwin/communication/slack` + `home/communication/slack` → `apps/communication/slack/`, aspect `slack`.
- `darwin/browsers/chromium/slack` (actually the darwin Chromium cask) + `home/browsers/chromium` → `apps/browsers/chromium/`, aspect `chromium`.
- `home/media/qbittorrent` (desktop client) → `apps/media/qbittorrent-client/`, aspect `qbittorrent-client`. The server is `services/media/qbittorrent`.
- `home/media/tools` → `apps/media/media-tools/`, aspect `media-tools`.
- `home/games/minecraft` → `apps/games/minecraft/`, aspect `minecraft`. The server is `services/gaming/minecraft-server`.

Rules: [../README.md](../README.md).
