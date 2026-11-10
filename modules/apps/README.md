# apps/

Applications a user runs.

| Sub-directory | Features (from `master`) |
|---|---|
| `browsers/` | `chrome`, `chromium`, `firefox` |
| `communication/` | `slack`, `telegram`, `viber`, `zoom` |
| `media/` | `vlc`, `shotwell`, `lightroom`, `qbittorrent-client`, `media-tools` |
| `productivity/` | `libreoffice` |
| `games/` | `minecraft` |

**No `default` selectors.** The app a user actually uses sets itself as the default (browser, player, office suite). `master`'s `browsers/default`, `media/players/default` and `productivity/offices/default` aren't ported. The same rule applies in `../cli/README.md`.

Examples:
- `darwin/communication/slack` + `home/communication/slack` → `apps/communication/slack/`, aspect `slack`.
- `darwin/browsers/chromium/slack` (actually the darwin Chromium cask) + `home/browsers/chromium` → `apps/browsers/chromium/`, aspect `chromium`.
- `home/media/qbittorrent` (desktop client) → `apps/media/qbittorrent-client/`, aspect `qbittorrent-client`. The server is `services/media/qbittorrent`.
- `home/media/tools` + repo-root `packages/media-tools` → `apps/media/media-tools/` (with `_package.nix`), aspect `media-tools`.
- `home/games/minecraft` → `apps/games/minecraft/`, aspect `minecraft`. The server is `services/gaming/minecraft-server`.

Rules: [../README.md](../README.md).
