# Backup Services

This directory contains NixOS modules for backup services using Restic.

## Modules

### restic
Client module for backing up hosts to a restic repository.

**Usage:**
```nix
nix-config.services.backup.restic = {
  enable = true;
  repository = "rest:http://server:8000/";
  passwordFile = "/var/lib/restic/password";
  paths = [ "/home" "/etc" ];
};
```

### restic-server
Server module for hosting a Restic REST server to receive backups.

**Usage:**
```nix
nix-config.services.backup.restic-server = {
  enable = true;
  dataDir = "/backups";
  listenAddress = "0.0.0.0:8000";
};
```

## Documentation

See the comprehensive documentation in the `docs/` directory:

- **[backup-with-restic.md](../../../docs/backup-with-restic.md)** - Complete guide with all features and options
- **[backup-examples.md](../../../docs/backup-examples.md)** - Ready-to-use configuration examples
- **[backup-quick-reference.md](../../../docs/backup-quick-reference.md)** - Quick reference for common commands

## Quick Start

### 1. Server Setup
```nix
{
  fileSystems."/backups" = {
    device = "/dev/disk/by-label/backups";
    fsType = "ext4";
  };

  nix-config.services.backup.restic-server = {
    enable = true;
    dataDir = "/backups";
  };

  networking.firewall.allowedTCPPorts = [ 8000 ];
}
```

### 2. Client Setup
```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://10.0.0.40:8000/";
    passwordFile = config.sops.secrets."restic-password".path;
    paths = [ "/home" "/etc" ];
    initialize = true;
  };

  sops.secrets."restic-password" = {
    sopsFile = ../../../modules/nixos/secrets.yaml;
    owner = "restic";
  };
}
```

### 3. Setup Secrets
```bash
# Edit secrets file
sops modules/nixos/secrets.yaml

# Add:
# restic-password: "your-secure-password"
```

## Features

### Restic Client
- ✅ Automatic scheduled backups
- ✅ Customizable paths and exclusions
- ✅ Retention policies (keep daily/weekly/monthly/yearly)
- ✅ Pre/post backup commands
- ✅ Repository integrity checks
- ✅ SOPS secrets integration
- ✅ Multiple repository backends (REST, S3, B2, etc.)

### Restic Server
- ✅ REST API for restic clients
- ✅ Private repositories per client
- ✅ Append-only mode
- ✅ HTTP authentication (htpasswd)
- ✅ TLS support
- ✅ Prometheus metrics
- ✅ Security hardening

## Common Commands

```bash
# Manual backup
sudo systemctl start restic-backups-default.service

# List snapshots
restic -r rest:http://server:8000/ snapshots

# Restore files
restic -r rest:http://server:8000/ restore latest --target /tmp/restore

# Check status
systemctl status restic-backups-default.timer
```

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Desktop   │         │     VM      │         │   Laptop    │
│             │         │             │         │             │
│   restic    │         │   restic    │         │   restic    │
│   client    │         │   client    │         │   client    │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
       │    HTTP REST API      │                       │
       └───────────┬───────────┴───────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │     Server      │
         │                 │
         │ restic-server   │
         │    :8000        │
         └────────┬────────┘
                  │
                  ▼
         ┌─────────────────┐
         │   USB Disk      │
         │   /backups      │
         └─────────────────┘
```

## Support

For issues or questions:
1. Check the documentation in `docs/`
2. Review the examples in `docs/backup-examples.md`
3. Use the quick reference: `docs/backup-quick-reference.md`
4. Check restic documentation: https://restic.readthedocs.io/

