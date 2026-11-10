# system/

Base OS features, shared across nixos, darwin and home where they apply.

| Sub-directory | Features (from `master`) |
|---|---|
| `<feature>/` | `boot`, `fs`, `locale`, `networking`, `nix`, `nix-ld`, `power`, `hibernation`, `homebrew` (darwin), `macos-defaults` (darwin `system/defaults`) |
| `disks/` | `disko`, `impermanence` (`nixos/disks/*`) |
| `types/` | The system types (below) |

Examples:
- `nixos/system/locale` + `darwin/system/locale` + `home/system/locale` → `system/locale/`, aspect `locale`, with three class parts.
- `darwin/system/defaults` → `system/macos-defaults/`, aspect `macos-defaults`.
- `nixos/disks/impermanence` → `system/disks/impermanence/`, aspect `impermanence`.

## System types

These follow Doc-Steve's system types: levels of base environment, each inheriting from the one before. Hosts and users both import them.

```
system-core ──▶ system-common ──┬──▶ system-server
                                └──▶ system-desktop
```

| Type | From `master` | What it is |
|---|---|---|
| `types/system-core/` | `*/roles/minimal` | The minimum every machine has. The installer ISOs use it. |
| `types/system-common/` | `*/roles/common` | The everyday base, merged across nixos, darwin and home. |
| `types/system-server/` | `nixos/roles/server` | The headless base, including its forced UTC. |
| `types/system-desktop/` | `*/roles/{desktop,graphical}` | The graphical base. |

Each type imports its parent (`imports = [ inputs.self.modules.<class>.system-common ];`) and has parts for every class it applies to. A type describes the environment, not the device or the purpose: devices go in `../hardware/devices/`, and purpose goes in `../roles/`.

Rules: [../README.md](../README.md).
