# Backup Setup Checklist

Use this checklist to set up your backup system from scratch.

## Prerequisites

- [ ] NixOS systems configured with this flake
- [ ] USB disk for backups (recommended: 2TB+)
- [ ] Network connectivity between hosts
- [ ] SOPS configured for secrets management

## Phase 1: Server Setup

### 1.1 Prepare USB Disk

- [ ] Connect USB disk to server
- [ ] Identify disk: `lsblk`
- [ ] Format disk: `sudo mkfs.ext4 -L backups /dev/sdX1`
- [ ] Get UUID: `sudo blkid /dev/sdX1`
- [ ] Note down UUID: ________________

### 1.2 Configure Server

- [ ] Add filesystem mount to server configuration:
  ```nix
  fileSystems."/backups" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
  ```

- [ ] Add restic-server configuration:
  ```nix
  nix-config.services.backup.restic-server = {
    enable = true;
    dataDir = "/backups";
    listenAddress = "0.0.0.0:8000";
    privateRepos = true;
    appendOnly = true;
  };
  ```

- [ ] Open firewall:
  ```nix
  networking.firewall.allowedTCPPorts = [ 8000 ];
  ```

- [ ] Build and deploy: `just deploy server`
- [ ] Verify mount: `df -h /backups`
- [ ] Verify server: `curl http://localhost:8000/`
- [ ] Check logs: `journalctl -u restic-rest-server -f`

## Phase 2: Secrets Setup

### 2.1 Generate Password

- [ ] Generate secure password:
  ```bash
  openssl rand -base64 32
  ```
- [ ] Save password to password manager
- [ ] Save password to encrypted backup location

### 2.2 Add to SOPS

- [ ] Edit secrets file:
  ```bash
  cd ~/Projects/Self/nix-config
  sops modules/nixos/secrets.yaml
  ```

- [ ] Add restic password:
  ```yaml
  restic-password: "YOUR-GENERATED-PASSWORD"
  ```

- [ ] Save and verify encryption

## Phase 3: Client Setup (Desktop)

### 3.1 Configure Desktop

- [ ] Add to `/systems/x86_64-linux/desktop/default.nix`:
  ```nix
  {
    nix-config.services.backup.restic = {
      enable = true;
      repository = "rest:http://10.0.0.40:8000/";  # Server IP
      passwordFile = config.sops.secrets."restic-password".path;
      
      paths = [
        "/home"
        "/etc"
      ];
      
      exclude = [
        "/home/*/.cache"
        "/home/*/Downloads"
      ];
      
      initialize = true;
    };

    sops.secrets."restic-password" = {
      sopsFile = ../../../modules/nixos/secrets.yaml;
      owner = "restic";
      group = "restic";
      mode = "0400";
    };
  }
  ```

- [ ] Build and deploy: `just deploy desktop`
- [ ] Verify service: `systemctl status restic-backups-default.timer`

### 3.2 Initialize Backup

- [ ] Start first backup: `sudo systemctl start restic-backups-default.service`
- [ ] Wait for completion: `sudo systemctl status restic-backups-default.service`
- [ ] Check logs: `journalctl -u restic-backups-default.service -f`
- [ ] Verify snapshot created:
  ```bash
  sudo -u restic restic -r rest:http://10.0.0.40:8000/ snapshots
  ```

## Phase 4: Additional Clients

### 4.1 VM Configuration

- [ ] Add to `/systems/x86_64-linux/vm/default.nix`:
  ```nix
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://10.0.0.40:8000/";
    passwordFile = config.sops.secrets."restic-password".path;
    paths = [ "/etc" "/var/lib" ];
    initialize = true;
  };
  
  sops.secrets."restic-password" = {
    sopsFile = ../../../modules/nixos/secrets.yaml;
    owner = "restic";
    group = "restic";
    mode = "0400";
  };
  ```

- [ ] Build and deploy: `just deploy vm`
- [ ] Initialize backup: `sudo systemctl start restic-backups-default.service`
- [ ] Verify snapshot

### 4.2 Server Self-Backup

- [ ] Add to `/systems/aarch64-linux/server/default.nix`:
  ```nix
  nix-config.services.backup.restic = {
    enable = true;
    repository = "rest:http://127.0.0.1:8000/";
    passwordFile = config.sops.secrets."restic-password".path;
    
    paths = [
      "/home"
      "/etc"
      "/var/lib"
    ];
    
    exclude = [
      "/backups"  # Don't backup the backup directory
    ];
    
    initialize = true;
  };
  ```

- [ ] Redeploy server: `just deploy server`
- [ ] Initialize backup
- [ ] Verify snapshot

## Phase 5: Testing

### 5.1 Verify All Hosts

For each host (desktop, vm, server):

- [ ] Check timer status:
  ```bash
  systemctl status restic-backups-default.timer
  ```

- [ ] Check last backup:
  ```bash
  systemctl list-timers restic-backups-default.timer
  ```

- [ ] View snapshots:
  ```bash
  sudo -u restic restic -r rest:http://10.0.0.40:8000/ snapshots
  ```

### 5.2 Test Restore

- [ ] Create test file:
  ```bash
  echo "Test backup content" > /tmp/test-backup.txt
  ```

- [ ] Run backup:
  ```bash
  sudo systemctl start restic-backups-default.service
  ```

- [ ] Delete test file:
  ```bash
  rm /tmp/test-backup.txt
  ```

- [ ] Restore file:
  ```bash
  sudo -u restic restic -r rest:http://10.0.0.40:8000/ restore latest --target /tmp/restore --path /tmp/test-backup.txt
  ```

- [ ] Verify restoration:
  ```bash
  cat /tmp/restore/tmp/test-backup.txt
  ```

### 5.3 Check Repository

- [ ] Check repository integrity:
  ```bash
  sudo -u restic restic -r rest:http://10.0.0.40:8000/ check
  ```

- [ ] View statistics:
  ```bash
  sudo -u restic restic -r rest:http://10.0.0.40:8000/ stats
  ```

- [ ] Check disk usage:
  ```bash
  df -h /backups
  ```

## Phase 6: Monitoring Setup

### 6.1 Create Monitoring Script

- [ ] Create `/usr/local/bin/backup-status.sh`:
  ```bash
  #!/usr/bin/env bash
  echo "=== Backup Status ==="
  echo ""
  echo "Disk Usage:"
  df -h /backups
  echo ""
  echo "Last Backup:"
  systemctl status restic-backups-default.service | grep "Active:"
  echo ""
  echo "Next Backup:"
  systemctl list-timers restic-backups-default.timer | grep restic
  echo ""
  echo "Snapshot Count:"
  sudo -u restic restic -r rest:http://127.0.0.1:8000/ snapshots | tail -1
  ```

- [ ] Make executable: `chmod +x /usr/local/bin/backup-status.sh`

### 6.2 Set Calendar Reminders

- [ ] Weekly: Check backup logs
- [ ] Monthly: Run repository check
- [ ] Quarterly: Test restore procedure
- [ ] Yearly: Replace backup disk

## Phase 7: Documentation

### 7.1 Document Setup

- [ ] Document server IP: ________________
- [ ] Document backup schedule: ________________
- [ ] Document retention policy: ________________
- [ ] Document emergency contacts: ________________

### 7.2 Store Recovery Information

Store in secure location (password manager, encrypted file, etc.):

- [ ] Restic repository password
- [ ] Server access credentials
- [ ] USB disk UUID
- [ ] Network configuration
- [ ] This checklist

## Phase 8: Ongoing Maintenance

### Weekly Tasks
- [ ] Check backup logs: `journalctl -u restic-backups-default.service --since "1 week ago"`
- [ ] Verify all hosts backed up
- [ ] Check disk space: `df -h /backups`

### Monthly Tasks
- [ ] Run repository check: `sudo systemctl start restic-backups-default-check.service`
- [ ] Review retention policy
- [ ] Verify timers are active: `systemctl list-timers | grep restic`

### Quarterly Tasks
- [ ] Full restore test
- [ ] Review and update exclusions
- [ ] Check USB disk health: `sudo smartctl -a /dev/sdX`
- [ ] Update documentation

### Yearly Tasks
- [ ] Review entire backup strategy
- [ ] Consider disk replacement
- [ ] Update emergency procedures
- [ ] Test disaster recovery

## Troubleshooting Reference

### Common Issues

**Can't connect to server:**
- Check server is running: `systemctl status restic-rest-server`
- Check firewall: `sudo iptables -L -n | grep 8000`
- Test connection: `curl http://SERVER:8000/`

**Permission denied:**
- Check password file: `ls -la /var/lib/restic/password`
- Fix permissions: `sudo chmod 400 /var/lib/restic/password`

**Repository locked:**
- Unlock: `sudo -u restic restic -r rest:http://SERVER:8000/ unlock`

**Out of space:**
- Check disk: `df -h /backups`
- Prune old backups: `sudo -u restic restic -r rest:http://SERVER:8000/ forget --keep-last 10 --prune`

## Success Criteria

- [x] All modules implemented
- [ ] Server running and accessible
- [ ] USB disk mounted and configured
- [ ] All clients configured
- [ ] All clients have at least one snapshot
- [ ] Repository integrity verified
- [ ] Restore test successful
- [ ] Monitoring in place
- [ ] Documentation complete

## Next Steps After Setup

1. Set up monitoring/alerting for failed backups
2. Configure off-site backup (B2, S3, etc.)
3. Set up backup rotation (multiple USB disks)
4. Document disaster recovery procedures
5. Train team on restore procedures

## Resources

- [Backup with Restic Guide](./backup-with-restic.md)
- [Configuration Examples](./backup-examples.md)
- [Quick Reference](./backup-quick-reference.md)
- [Module README](../modules/nixos/services/backup/README.md)
- [Restic Documentation](https://restic.readthedocs.io/)

