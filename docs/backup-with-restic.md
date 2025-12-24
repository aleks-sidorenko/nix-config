# Backup with Restic

This document describes how to use the Restic backup modules in this NixOS configuration.

## Overview

The backup system consists of two modules:

1. **restic** - Client module for backing up hosts
2. **restic-server** - Server module for receiving and storing backups

## Architecture

The typical setup involves:
- A server running `restic-server` with a USB disk mounted at `/backup`
- Multiple clients running `restic` that backup to the server
- Automated daily backups with retention policies

## Server Configuration

### Basic Setup

On your backup server (e.g., the `server` host):

```nix
{
  nix-config.services.backup.restic-server = {
    enable = true;
    dataDir = "/backup";  # USB disk mount point
    listenAddress = "0.0.0.0:8000";
    privateRepos = true;  # Each client gets its own subdirectory
    appendOnly = false;   # Set to true for extra safety
  };

  # Open firewall port for clients to connect
  networking.firewall.allowedTCPPorts = [ 8000 ];
}
```

### With Authentication

For better security, use htpasswd authentication:

```nix
{
  nix-config.services.backup.restic-server = {
    enable = true;
    dataDir = "/backup";
    listenAddress = "0.0.0.0:8000";
    privateRepos = true;
    htpasswdFile = "/var/lib/restic/htpasswd";
  };

  # Create htpasswd file with sops or manually
  # htpasswd -B -c /var/lib/restic/htpasswd username
}
```

### With TLS

For secure connections over the network:

```nix
{
  nix-config.services.backup.restic-server = {
    enable = true;
    dataDir = "/backup";
    listenAddress = "0.0.0.0:8443";
    privateRepos = true;
    tls = {
      enable = true;
      certFile = "/var/lib/restic/cert.pem";
      keyFile = "/var/lib/restic/key.pem";
    };
  };
}
```

### Append-Only Mode

For maximum safety against ransomware and accidental deletion:

```nix
{
  nix-config.services.backup.restic-server = {
    enable = true;
    appendOnly = true;  # Prevents deletion of backups via the REST API
  };
}
```

## Client Configuration

### Basic Setup

On hosts that need to be backed up:

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://10.0.0.40:8000/";
    passwordFile = "/var/lib/restic/password";
    
    paths = [
      "/home"
      "/etc"
      "/var"
      "/root"
    ];
    
    exclude = [
      "*.tmp"
      "*.cache"
      "/var/cache"
      "/var/tmp"
      "/home/*/.cache"
    ];
    
    # Backup daily at random time within 1 hour window
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    
    # Keep 7 daily, 4 weekly, 6 monthly, 2 yearly backups
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];
    
    initialize = true;  # Initialize repo on first run
  };
}
```

### With Authentication

If the server uses htpasswd authentication:

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://username:password@10.0.0.40:8000/";
    # Or use repositoryFile for better security:
    repositoryFile = "/var/lib/restic/repository";
    passwordFile = "/var/lib/restic/password";
  };
  
  # Store credentials in SOPS:
  # sops.secrets."restic-repository" = {
  #   sopsFile = ../secrets.yaml;
  #   path = "/var/lib/restic/repository";
  #   owner = "restic";
  # };
  # sops.secrets."restic-password" = {
  #   sopsFile = ../secrets.yaml;
  #   path = "/var/lib/restic/password";
  #   owner = "restic";
  # };
}
```

### Custom Paths and Exclusions

Customize what to backup:

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    
    paths = [
      "/home"
      "/etc/nixos"
      "/var/lib/postgres"
      "/srv/data"
    ];
    
    exclude = [
      # Temporary files
      "*.tmp"
      "*.swp"
      "*.cache"
      
      # Large directories
      "/home/*/Downloads"
      "/home/*/.local/share/Steam"
      "/home/*/.cache"
      
      # System directories
      "/var/cache"
      "/var/tmp"
      "/var/log"
    ];
  };
}
```

### With Pre/Post Backup Commands

For database dumps or other preparations:

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    
    backupPrepareCommand = ''
      # Dump PostgreSQL database before backup
      ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dumpall > /var/backup/postgres.sql
    '';
    
    backupCleanupCommand = ''
      # Remove temporary dump after backup
      rm -f /var/backup/postgres.sql
    '';
    
    paths = [
      "/home"
      "/var/backup"
    ];
  };
}
```

### Custom Backup Schedule

Adjust the backup schedule:

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    
    # Backup twice daily
    timerConfig = {
      OnCalendar = [ "02:00" "14:00" ];
      Persistent = true;
    };
    
    # Or backup hourly
    # timerConfig = {
    #   OnCalendar = "hourly";
    #   Persistent = true;
    # };
    
    # Or specific days
    # timerConfig = {
    #   OnCalendar = "Mon,Wed,Fri 03:00";
    #   Persistent = true;
    # };
  };
}
```

### Custom Retention Policy

Adjust how long backups are kept:

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    
    # Keep more recent backups
    pruneOpts = [
      "--keep-daily 14"    # 2 weeks of daily backups
      "--keep-weekly 8"    # 2 months of weekly backups
      "--keep-monthly 12"  # 1 year of monthly backups
      "--keep-yearly 5"    # 5 years of yearly backups
    ];
    
    # Or simpler: keep last N snapshots
    # pruneOpts = [
    #   "--keep-last 30"
    # ];
  };
}
```

## USB Disk Setup for Server

### Mounting the USB Disk

Add to your server configuration:

```nix
{
  # Find USB disk UUID with: lsblk -f
  fileSystems."/backup" = {
    device = "/dev/disk/by-uuid/YOUR-USB-DISK-UUID";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
  
  # Or use labels
  # fileSystems."/backup" = {
  #   device = "/dev/disk/by-label/backup";
  #   fsType = "ext4";
  #   options = [ "defaults" "nofail" ];
  # };
}
```

### Format and Label USB Disk

```bash
# Find the disk
lsblk

# Format as ext4 (CAUTION: This erases all data!)
sudo mkfs.ext4 -L backups /dev/sdX1

# Create mount point
sudo mkdir -p /backup

# Mount it
sudo mount /dev/disk/by-label/backup /backup

# Set permissions
sudo chown restic:restic /backup
sudo chmod 700 /backup
```

## Setting Up Secrets

### Using SOPS (Recommended)

1. Add secrets to `modules/nixos/secrets.yaml`:

```yaml
restic-password: ENC[AES256_GCM,...]
restic-repository: ENC[AES256_GCM,...]
```

2. Configure in your host:

```nix
{
  sops.secrets."restic-password" = {
    sopsFile = ../../modules/nixos/secrets.yaml;
    owner = "restic";
    group = "restic";
    mode = "0400";
  };
  
  nix-config.services.backup.restic = {
    enable = true;
    passwordFile = config.sops.secrets."restic-password".path;
  };
}
```

### Manual Setup

Create password file manually:

```bash
# Create password file
sudo mkdir -p /var/lib/restic
echo "your-secure-password" | sudo tee /var/lib/restic/password
sudo chmod 400 /var/lib/restic/password
sudo chown restic:restic /var/lib/restic/password
```

## Managing Backups

### Manual Backup

```bash
# Trigger a backup manually
sudo systemctl start restic-backups-default.service

# Check backup status
sudo systemctl status restic-backups-default.service
```

### View Snapshots

```bash
# List all snapshots
sudo -u restic restic -r rest:http://10.0.0.40:8000/ snapshots

# Show latest snapshot
sudo -u restic restic -r rest:http://10.0.0.40:8000/ snapshots --latest 1
```

### Restore Files

```bash
# Restore entire snapshot to /tmp/restore
sudo -u restic restic -r rest:http://10.0.0.40:8000/ restore latest --target /tmp/restore

# Restore specific path
sudo -u restic restic -r rest:http://10.0.0.40:8000/ restore latest --target /tmp/restore --path /home/user

# Restore to original location
sudo -u restic restic -r rest:http://10.0.0.40:8000/ restore latest --target /
```

### Check Repository

```bash
# Check repository integrity
sudo systemctl start restic-backups-default-check.service

# Or manually
sudo -u restic restic -r rest:http://10.0.0.40:8000/ check
```

### Prune Old Backups

```bash
# Prune according to retention policy (done automatically)
sudo -u restic restic -r rest:http://10.0.0.40:8000/ forget --prune --keep-daily 7 --keep-weekly 4
```

### Repository Statistics

```bash
# Show repository stats
sudo -u restic restic -r rest:http://10.0.0.40:8000/ stats

# Show stats for latest snapshot
sudo -u restic restic -r rest:http://10.0.40:8000/ stats latest
```

## Troubleshooting

### Check Logs

```bash
# View recent backup logs
sudo journalctl -u restic-backups-default.service -n 50

# Follow logs in real-time
sudo journalctl -u restic-backups-default.service -f

# View server logs
sudo journalctl -u restic-rest-server.service -n 50
```

### Test Connection

```bash
# Test if server is reachable
curl http://10.0.0.40:8000/

# Test backup connection
sudo -u restic restic -r rest:http://10.0.0.40:8000/ snapshots
```

### Common Issues

**Repository already exists:**
- Set `initialize = false;` after first run

**Permission denied:**
- Check file permissions on `/var/lib/restic/password`
- Ensure restic user has access to backup paths

**Connection refused:**
- Check if restic-server is running: `systemctl status restic-rest-server`
- Verify firewall settings
- Check server address and port

**Out of space:**
- Check USB disk space: `df -h /backup`
- Adjust retention policy to keep fewer backups
- Run prune to free up space

## Example Configurations

### Desktop Workstation

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://server.local:8000/";
    passwordFile = config.sops.secrets."restic-password".path;
    
    paths = [
      "/home"
      "/etc"
    ];
    
    exclude = [
      "/home/*/.cache"
      "/home/*/Downloads"
      "/home/*/.local/share/Steam"
    ];
    
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };
}
```

### Server with Databases

```nix
{
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://backup-server.local:8000/";
    passwordFile = "/var/lib/restic/password";
    
    backupPrepareCommand = ''
      mkdir -p /var/backup
      sudo -u postgres pg_dumpall > /var/backup/postgres.sql
    '';
    
    backupCleanupCommand = ''
      rm -rf /var/backup
    '';
    
    paths = [
      "/var/lib"
      "/etc"
      "/var/backup"
    ];
    
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
    };
    
    pruneOpts = [
      "--keep-daily 30"
      "--keep-weekly 12"
      "--keep-monthly 24"
    ];
  };
}
```

### Backup Server

```nix
{
  # Mount USB disk
  fileSystems."/backup" = {
    device = "/dev/disk/by-label/backup";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # Enable restic server
  nix-config.services.backup.restic-server = {
    enable = true;
    dataDir = "/backup";
    listenAddress = "0.0.0.0:8000";
    privateRepos = true;
    appendOnly = true;  # Extra safety
  };

  # Open firewall
  networking.firewall.allowedTCPPorts = [ 8000 ];
}
```

## Additional Resources

- [Restic Documentation](https://restic.readthedocs.io/)
- [Restic REST Server](https://github.com/restic/rest-server)
- [NixOS Restic Module](https://search.nixos.org/options?query=services.restic)

