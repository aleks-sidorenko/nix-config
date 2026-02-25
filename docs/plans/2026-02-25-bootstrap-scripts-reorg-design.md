# Bootstrap Scripts Reorganization

## Goal

Move bootstrap scripts from `scripts/` top-level into `scripts/bootstrap/` and rename them to match justfile command names. `common.sh` stays at `scripts/` as shared utility.

## Current Structure

```
scripts/
  common.sh
  secrets.sh
  deploy.sh
  rpi/
    firmware.sh
```

## Target Structure

```
scripts/
  common.sh
  bootstrap/
    bootstrap-secrets.sh
    bootstrap-deploy.sh
    bootstrap-rpi-firmware.sh
```

## Changes

### Script moves and renames

| From | To |
|---|---|
| `scripts/secrets.sh` | `scripts/bootstrap/bootstrap-secrets.sh` |
| `scripts/deploy.sh` | `scripts/bootstrap/bootstrap-deploy.sh` |
| `scripts/rpi/firmware.sh` | `scripts/bootstrap/bootstrap-rpi-firmware.sh` |

### Script content changes

- `bootstrap-secrets.sh`: update `source "$SCRIPT_DIR/common.sh"` → `source "$SCRIPT_DIR/../common.sh"`
- `bootstrap-deploy.sh`: update `source "$SCRIPT_DIR/common.sh"` → `source "$SCRIPT_DIR/../common.sh"`
- `bootstrap-rpi-firmware.sh`: no source change needed (doesn't source common.sh)

### Justfile path updates

- `./scripts/secrets.sh` → `./scripts/bootstrap/bootstrap-secrets.sh`
- `./scripts/deploy.sh` → `./scripts/bootstrap/bootstrap-deploy.sh`
- `scripts/rpi/firmware.sh` → `./scripts/bootstrap/bootstrap-rpi-firmware.sh`
- `bootstrap-validate` shellcheck paths updated

### CLAUDE.md updates

Update "Important Files" section to reflect new paths.

### Removed

- `scripts/rpi/` directory (empty after move)
