# Backup Configuration Examples

This document provides ready-to-use configuration examples for the Restic backup modules.

## Quick Start

### 1. Server Configuration (Raspberry Pi)

Add to `/systems/aarch64-linux/server/default.nix`:

```nix
{
  lib,
  modulesPath,
  inputs,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./disks.nix
  ];
  
  # ... existing configuration ...

  ${namespace} = {
    roles = {
      server = enabled;
      media-server = enabled;
      smart-home = enabled;
      gaming-server = enabled;
    };

    hardware.raspberry-pi-4 = enabled;

    # Add backup server
    services.backup.restic-server = {
      enable = true;
      dataDir = "/backup";
      listenAddress = "0.0.0.0:8000";
      privateRepos = true;
      appendOnly = true;  # Prevent accidental deletion
    };
  };

  # Mount USB backup drive
  fileSystems."/backup" = {
    device = "/dev/disk/by-label/backup";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # Open firewall for backup clients
  networking.firewall.allowedTCPPorts = [ 8000 ];

  # Backup the server itself to the USB disk
  ${namespace}.services.backup.restic = {
    enable = true;
    repository = "rest:http://127.0.0.1:8000/";
    passwordFile = config.sops.secrets."restic-password".path;
    
    paths = [
      "/home"
      "/etc"
      "/var/lib"
      "/root"
    ];
    
    exclude = [
      "/var/cache"
      "/var/tmp"
      "/var/log"
      # Don't backup the backup directory itself
      "/backup"
    ];
    
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
    };
    
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
    
    initialize = true;
  };

  # Add SOPS secret for restic password
  sops.secrets."restic-password" = {
    sopsFile = ../../../modules/nixos/secrets.yaml;
    owner = "restic";
    group = "restic";
    mode = "0400";
  };

  system.stateVersion = "25.05";
}
```

### 2. Desktop Configuration

Add to `/systems/x86_64-linux/desktop/default.nix`:

```nix
{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];

  ${namespace} = {
    roles = {
      desktop = {
        enable = true;
      };
    };

    services = {
      virtualisation.kvm = enabled;
      
      # Add backup client
      backup.restic = {
        enable = true;
        repository = "rest:http://10.0.0.40:8000/";  # Server IP
        passwordFile = config.sops.secrets."restic-password".path;
        
        paths = [
          "/home"
          "/etc"
        ];
        
        exclude = [
          # Caches
          "/home/*/.cache"
          "/home/*/.local/share/Trash"
          
          # Large directories
          "/home/*/Downloads"
          "/home/*/.local/share/Steam"
          "/home/*/.local/share/lutris"
          
          # Temporary files
          "*.tmp"
          "*.cache"
          "*.log"
        ];
        
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "2h";  # Spread backups across 2 hour window
        };
        
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 3"
        ];
        
        initialize = true;
      };
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };

  # Add SOPS secret for restic password (must match server password)
  sops.secrets."restic-password" = {
    sopsFile = ../../../modules/nixos/secrets.yaml;
    owner = "restic";
    group = "restic";
    mode = "0400";
  };

  system.stateVersion = "25.05";
}
```

### 3. VM Configuration

Add to `/systems/x86_64-linux/vm/default.nix`:

```nix
{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];

  ${namespace} = {
    services = {
      backup.restic = {
        enable = true;
        repository = "rest:http://10.0.0.40:8000/";
        passwordFile = config.sops.secrets."restic-password".path;
        
        # For VMs, backup only essential data
        paths = [
          "/etc"
          "/var/lib"
          "/root"
        ];
        
        exclude = [
          "/var/cache"
          "/var/tmp"
          "/var/log"
        ];
        
        # Less frequent backups for VMs
        timerConfig = {
          OnCalendar = "02:00";
          Persistent = true;
        };
        
        # Shorter retention for VMs
        pruneOpts = [
          "--keep-daily 3"
          "--keep-weekly 2"
          "--keep-monthly 1"
        ];
        
        initialize = true;
      };
    };
  };

  sops.secrets."restic-password" = {
    sopsFile = ../../../modules/nixos/secrets.yaml;
    owner = "restic";
    group = "restic";
    mode = "0400";
  };

  system.stateVersion = "25.05";
}
```

## Advanced Configurations

### Server with Database Backups

If your server runs databases (PostgreSQL, MySQL, etc.), dump them before backup:

```nix
{
  ${namespace}.services.backup.restic = {
    enable = true;
    repository = "rest:http://127.0.0.1:8000/";
    passwordFile = config.sops.secrets."restic-password".path;
    
    backupPrepareCommand = ''
      mkdir -p /var/backup
      
      # Backup PostgreSQL
      ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dumpall > /var/backup/postgres.sql
      
      # Backup Home Assistant if enabled
      if systemctl is-active --quiet home-assistant; then
        cp -r /var/lib/home-assistant /var/backup/
      fi
    '';
    
    backupCleanupCommand = ''
      rm -rf /var/backup
    '';
    
    paths = [
      "/home"
      "/etc"
      "/var/lib"
      "/var/backup"
    ];
    
    timerConfig = {
      OnCalendar = "02:00";
      Persistent = true;
    };
  };
}
```

### Backup with Custom Schedule per Host

Different backup schedules for different systems:

```nix
# Desktop - backup during lunch and night
{
  ${namespace}.services.backup.restic.timerConfig = {
    OnCalendar = [ "12:00" "02:00" ];
    Persistent = true;
  };
}

# Server - backup once at night
{
  ${namespace}.services.backup.restic.timerConfig = {
    OnCalendar = "02:00";
    Persistent = true;
  };
}

# Laptop - backup every 6 hours when connected
{
  ${namespace}.services.backup.restic.timerConfig = {
    OnCalendar = "*-*-* 00,06,12,18:00:00";
    Persistent = true;
  };
}
```

### Backup Server with Multiple Storage Locations

Use bind mounts or multiple server instances:

```nix
{
  # Main USB backup
  fileSystems."/backup/main" = {
    device = "/dev/disk/by-label/backup-main";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # Secondary backup (another USB or network drive)
  fileSystems."/backup/secondary" = {
    device = "/dev/disk/by-label/backup-secondary";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # Primary restic server on port 8000
  ${namespace}.services.backup.restic-server = {
    enable = true;
    dataDir = "/backup/main";
    listenAddress = "0.0.0.0:8000";
    privateRepos = true;
  };

  # Create a second systemd service for secondary backups
  systemd.services.restic-rest-server-secondary = {
    description = "Restic REST Server (Secondary)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "restic";
      Group = "restic";
      ExecStart = "${pkgs.restic-rest-server}/bin/rest-server --path /backup/secondary --listen 0.0.0.0:8001 --private-repos";
      Restart = "on-failure";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8000 8001 ];
}
```

### Per-User Backups

Backup each user's home directory separately:

```nix
{
  ${namespace}.services.backup.restic = {
    enable = true;
    repository = "rest:http://10.0.0.40:8000/desktop-user1";
    passwordFile = "/home/user1/.config/restic/password";
    user = "user1";
    
    paths = [
      "/home/user1"
    ];
    
    exclude = [
      "/home/user1/.cache"
      "/home/user1/Downloads"
    ];
  };
}
```

## Setting Up Secrets

### Step 1: Add to secrets.yaml

Edit `modules/nixos/secrets.yaml`:

```bash
# Edit the secrets file
cd $FLAKE_DIR
sops modules/nixos/secrets.yaml
```

Add the following key:

```yaml
restic-password: "your-secure-password-here"
```

### Step 2: Encrypt the Secret

The password will be automatically encrypted when you save the file with sops.

### Step 3: Generate New Password

To generate a secure password:

```bash
# Generate a random password
openssl rand -base64 32
```

## USB Disk Setup

### Format USB Disk

```bash
# 1. Find your USB disk
lsblk

# 2. Format the disk (replace sdX with your device)
sudo mkfs.ext4 -L backups /dev/sdX1

# 3. Get UUID
sudo blkid /dev/sdX1

# 4. Create mount point
sudo mkdir -p /backup
```

### Add to Server Configuration

Use UUID for more reliable mounting:

```nix
{
  fileSystems."/backup" = {
    device = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
}
```

Or use label:

```nix
{
  fileSystems."/backup" = {
    device = "/dev/disk/by-label/backup";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
}
```

## Testing the Setup

### 1. Build and Switch

```bash
# On server
cd $FLAKE_DIR
just deploy server

# On desktop
just deploy desktop
```

### 2. Initialize Repository (First Time)

```bash
# On each client, trigger first backup
sudo systemctl start restic-backups-default.service

# Check status
sudo systemctl status restic-backups-default.service
```

### 3. Verify Backups

```bash
# On client, list snapshots
sudo -u restic restic -r rest:http://10.0.0.40:8000/ snapshots

# On server, check backup directory
ls -lah /backup/
```

### 4. Test Restore

```bash
# Restore a file to /tmp
sudo -u restic restic -r rest:http://10.0.0.40:8000/ restore latest --target /tmp/restore --path /home/user/important-file.txt
```

## Monitoring

### Check Backup Status

```bash
# View last backup time
systemctl status restic-backups-default.timer
systemctl status restic-backups-default.service

# View logs
journalctl -u restic-backups-default.service -n 100
```

### Check Disk Usage

```bash
# On server
df -h /backup

# In restic
sudo -u restic restic -r rest:http://127.0.0.1:8000/ stats
```

### Set Up Alerts (Optional)

Create a systemd service to send alerts on backup failure:

```nix
{
  systemd.services.restic-backups-default = {
    onFailure = [ "backup-failed-notification.service" ];
  };

  systemd.services.backup-failed-notification = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemd-cat -t restic-backup echo 'Backup failed!'";
    };
  };
}
```

## Maintenance

### Regular Tasks

1. **Monthly**: Check backup integrity
   ```bash
   sudo systemctl start restic-backups-default-check.service
   ```

2. **Monthly**: Verify disk health
   ```bash
   sudo smartctl -a /dev/sdX
   ```

3. **Quarterly**: Test restore procedure

4. **Yearly**: Consider rotating backup drives

### Cleanup

```bash
# Remove old snapshots manually
sudo -u restic restic -r rest:http://10.0.0.40:8000/ forget --keep-last 10 --prune

# Check repository
sudo -u restic restic -r rest:http://10.0.0.40:8000/ check
```

