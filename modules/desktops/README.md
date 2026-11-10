# desktops/

Window managers, desktop environments, their addons, and styling.

| Sub-directory | Features (from `master`) |
|---|---|
| `<feature>/` | `hyprland`, `gnome`, `aerospace`, `monitors`, `wallpaper` |
| `addons/` | `greetd`, `gammastep`, `gtk`, `kanshi`, `nautilus`, `qt`, `rofi`, `swaylock`, `swaync`, `waybar`, `wlogout`, `wlsunset`, `xdg`, plus hyprland's `hypridle`, `hyprlock`, `hyprpaper`, `pyprland` |
| `styles/` | `stylix` |

Each addon is a program of its own, so it's a feature under `addons/`, not nested inside `hyprland/`. Files inside a feature directory (`gnome/`'s extensions, `hyprland/`'s window rules) belong to that one aspect.

Examples:
- `home/desktops/hyprland/addons/hyprlock` → `desktops/addons/hyprlock/`, aspect `hyprlock`.
- `nixos/desktops/hyprland` + `home/desktops/hyprland` → `desktops/hyprland/`, aspect `hyprland`.
- `nixos/styles/stylix` + `home/styles/stylix` + repo-root `packages/wallpapers` → `desktops/styles/stylix/` (with `_package.nix`), aspect `stylix`.
- `home/desktops/gnome/profiles/child` → `../users/profiles/child/` (its gnome part).

Rules: [../README.md](../README.md).
