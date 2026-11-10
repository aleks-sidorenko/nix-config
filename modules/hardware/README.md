# hardware/

Hardware support, and the features that describe a kind of device.

| Sub-directory | Features (from `master`) |
|---|---|
| `<feature>/` | `audio`, `bluetooth`, `zsa` (`nixos/hardware/*`) |
| `video/` | `nvidia`, `nouveau` (`nixos/hardware/video/*`) |
| `devices/` | `laptop`, `homebook`, `macbook`, `phone`: today's device roles |

Examples:
- `nixos/hardware/video/nvidia` → `hardware/video/nvidia/`, aspect `nvidia`.
- `darwin/roles/macbook` + `home/roles/macbook` → `hardware/devices/macbook/`, aspect `macbook`.
- `nixos/hardware/phone` + `home/roles/phone` + repo-root `packages/phone-tools` → `hardware/devices/phone/` (with `_package.nix`), aspect `phone`.

A host's own `_hardware.nix` (its disks and kernel modules) stays in `../hosts/<host>/`.

Rules: [../README.md](../README.md).
