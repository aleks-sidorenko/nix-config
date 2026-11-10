# roles/

Purpose bundles: what a machine is for. A role is a feature that imports other features, and may import the system type it needs (`home-server` imports `system-server`).

From `master`:
- `home-server`
- `media-server`
- `gaming-server`
- `backup`, `backup-server`
- `gaming`
- `work`
- `development`
- `media`
- `communication`
- `agent-host` (today's nixos/darwin `agent-host` + home `agent`)

**You can't subtract an import, so keep roles small.** Anything a host might not want is imported by the host, not baked into a role. On `master`:
- `workbook` sets `qbittorrent.enable = mkForce false`. Instead, the `media` role doesn't carry `qbittorrent-client`.

If the same mix of type and roles shows up on two hosts, it becomes a role.

Not roles:
- machine shape (`minimal`, `common`, `server`, `desktop`, `graphical`) → `../system/types/`
- devices (`laptop`, `homebook`, `macbook`, `phone`) → `../hardware/devices/`
- people (`child`) → `../users/profiles/`

Examples:
- `nixos/roles/home-server` → `roles/home-server/`, aspect `home-server`.
- `darwin/roles/work` + `home/roles/work` → `roles/work/`, aspect `work`.

Rules: [../README.md](../README.md).
