# hosts/

One directory per machine:
- `<host>.nix` defines `flake.modules.<class>.<host>` and its one builder line (`flake.nixosConfigurations.<host> = inputs.self.lib.mkNixos "<system>" "<host>";`, or `mkDarwin`).
- `_hardware.nix` and `_disks.nix` are plain modules, skipped by import-tree and imported by `<host>.nix`.

A host owns its bare name. It's usually one role, its user, its hardware and a few host-only settings.

From `master`:
- `systems/x86_64-linux/server` → `hosts/server/`
- `systems/aarch64-darwin/workbook` → `hosts/workbook/`
- `systems/x86_64-install-iso/minimal-x86_64` → `hosts/installer/installer.nix` (done). It outputs `nixosConfigurations.installer` and `packages.x86_64-linux.installer-iso`, built with `just iso-build`. The aarch64 ISO isn't ported.
- `systems/aarch64-linux/server-vm` → `hosts/server-vm/` (out of scope for now)

Home-manager runs inside the host, so `homes/<arch>/<user>@<host>` splits between `../users/<name>/` and here.

Rules: [../README.md](../README.md).
