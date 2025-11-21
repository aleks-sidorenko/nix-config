# Restic Backup Quick Reference

## Common Commands

### Backup Operations

```bash
# Manual backup
sudo systemctl start restic-backups-default.service

# Check backup status
sudo systemctl status restic-backups-default.service

# View backup logs
journalctl -u restic-backups-default.service -f

# Check next scheduled backup
systemctl list-timers restic-backups-default.timer
```

### View Snapshots

```bash
# List all snapshots
restic -r rest:http://SERVER:8000/ snapshots

# List snapshots with more details
restic -r rest:http://SERVER:8000/ snapshots --long

# Show latest snapshot
restic -r rest:http://SERVER:8000/ snapshots --latest 1

# Show snapshots for specific path
restic -r rest:http://SERVER:8000/ snapshots --path /home
```

### Restore Operations

```bash
# Restore entire latest snapshot
restic -r rest:http://SERVER:8000/ restore latest --target /tmp/restore

# Restore specific path
restic -r rest:http://SERVER:8000/ restore latest --target /tmp/restore --path /home/user/Documents

# Restore specific snapshot by ID
restic -r rest:http://SERVER:8000/ restore abc123de --target /tmp/restore

# Restore to original location
restic -r rest:http://SERVER:8000/ restore latest --target /

# List files in snapshot
restic -r rest:http://SERVER:8000/ ls latest

# List files in specific path
restic -r rest:http://SERVER:8000/ ls latest /home/user
```

### Repository Management

```bash
# Check repository integrity
restic -r rest:http://SERVER:8000/ check

# Check with data verification
restic -r rest:http://SERVER:8000/ check --read-data

# View repository statistics
restic -r rest:http://SERVER:8000/ stats

# View statistics by snapshot
restic -r rest:http://SERVER:8000/ stats latest

# View repository size
restic -r rest:http://SERVER:8000/ stats --mode raw-data
```

### Pruning and Cleanup

```bash
# List snapshots that would be removed
restic -r rest:http://SERVER:8000/ forget --keep-daily 7 --keep-weekly 4 --dry-run

# Remove old snapshots (doesn't free space yet)
restic -r rest:http://SERVER:8000/ forget --keep-daily 7 --keep-weekly 4

# Remove old snapshots and free space
restic -r rest:http://SERVER:8000/ forget --prune --keep-daily 7 --keep-weekly 4

# Only prune (after forget)
restic -r rest:http://SERVER:8000/ prune
```

### Search and Find

```bash
# Find files by name
restic -r rest:http://SERVER:8000/ find filename.txt

# Find files by pattern
restic -r rest:http://SERVER:8000/ find "*.pdf"

# Find files in specific path
restic -r rest:http://SERVER:8000/ find --path /home/user "*.jpg"

# Show which snapshot contains a file
restic -r rest:http://SERVER:8000/ find important-file.txt --show-pack-id
```

### Diff and Compare

```bash
# Compare two snapshots
restic -r rest:http://SERVER:8000/ diff snapshot1 snapshot2

# Show changes since last backup
restic -r rest:http://SERVER:8000/ diff latest

# Show only added files
restic -r rest:http://SERVER:8000/ diff --metadata snapshot1 snapshot2
```

### Mount (Browse Backups as Filesystem)

```bash
# Mount all snapshots
mkdir -p /tmp/restic-mount
restic -r rest:http://SERVER:8000/ mount /tmp/restic-mount

# Mount specific snapshot
restic -r rest:http://SERVER:8000/ mount --snapshot-template "{{.Time.Format \"2006-01-02\"}}" /tmp/restic-mount

# Unmount
fusermount -u /tmp/restic-mount
```

## Environment Variables

Instead of typing `-r rest:http://SERVER:8000/` every time, set these:

```bash
export RESTIC_REPOSITORY="rest:http://SERVER:8000/"
export RESTIC_PASSWORD_FILE="/var/lib/restic/password"

# Now you can use restic without -r
restic snapshots
restic restore latest --target /tmp/restore
```

## NixOS Service Commands

### Systemd Service Management

```bash
# Start backup now
sudo systemctl start restic-backups-default.service

# Stop running backup
sudo systemctl stop restic-backups-default.service

# Check status
sudo systemctl status restic-backups-default.service

# Enable automatic backups
sudo systemctl enable restic-backups-default.timer

# Disable automatic backups
sudo systemctl disable restic-backups-default.timer

# Check timer schedule
systemctl status restic-backups-default.timer
systemctl list-timers restic-backups-default.timer
```

### Server Service Management

```bash
# Restart restic server
sudo systemctl restart restic-rest-server.service

# Check server status
sudo systemctl status restic-rest-server.service

# View server logs
journalctl -u restic-rest-server.service -f

# Stop server
sudo systemctl stop restic-rest-server.service

# Start server
sudo systemctl start restic-rest-server.service
```

### View Logs

```bash
# Recent backup logs
journalctl -u restic-backups-default.service -n 100

# Follow logs in real-time
journalctl -u restic-backups-default.service -f

# Logs since yesterday
journalctl -u restic-backups-default.service --since yesterday

# Logs for specific date
journalctl -u restic-backups-default.service --since "2025-01-01" --until "2025-01-02"

# Server logs
journalctl -u restic-rest-server.service -n 100
```

## Useful One-Liners

```bash
# Total size of backups
restic -r rest:http://SERVER:8000/ stats --mode raw-data | grep "Total Size"

# Number of snapshots
restic -r rest:http://SERVER:8000/ snapshots | wc -l

# Latest backup time
restic -r rest:http://SERVER:8000/ snapshots --latest 1 --json | jq -r '.[0].time'

# List all hosts backing up to server
restic -r rest:http://SERVER:8000/ snapshots --group-by host

# Size of specific path in backup
restic -r rest:http://SERVER:8000/ stats latest --mode restore-size --path /home

# Find large files (>100MB)
restic -r rest:http://SERVER:8000/ find --size +100M

# Restore single file quickly
restic -r rest:http://SERVER:8000/ dump latest /path/to/file > restored-file

# Check if file exists in backup
restic -r rest:http://SERVER:8000/ find filename.txt && echo "Found" || echo "Not found"
```

## Troubleshooting

### Connection Issues

```bash
# Test server connectivity
curl http://SERVER:8000/

# Test with authentication
curl -u username:password http://SERVER:8000/

# Check if port is open
nc -zv SERVER 8000

# Check firewall
sudo iptables -L -n | grep 8000
```

### Permission Issues

```bash
# Fix password file permissions
sudo chown restic:restic /var/lib/restic/password
sudo chmod 400 /var/lib/restic/password

# Check backup directory permissions
ls -la /backups

# Fix backup directory permissions
sudo chown -R restic:restic /backups
sudo chmod 700 /backups
```

### Repository Issues

```bash
# Unlock locked repository
restic -r rest:http://SERVER:8000/ unlock

# Rebuild repository index
restic -r rest:http://SERVER:8000/ rebuild-index

# Check and repair repository
restic -r rest:http://SERVER:8000/ check --read-data
restic -r rest:http://SERVER:8000/ repair index
restic -r rest:http://SERVER:8000/ repair snapshots
```

### Disk Space Issues

```bash
# Check backup disk usage
df -h /backups

# Check repository size
restic -r rest:http://SERVER:8000/ stats --mode raw-data

# Remove old snapshots to free space
restic -r rest:http://SERVER:8000/ forget --keep-last 10 --prune

# Check for unreferenced data
restic -r rest:http://SERVER:8000/ prune --dry-run
```

### Performance Issues

```bash
# Backup with progress
restic -r rest:http://SERVER:8000/ backup /path --verbose

# Backup with statistics
restic -r rest:http://SERVER:8000/ backup /path --verbose=2

# Check repository performance
time restic -r rest:http://SERVER:8000/ check

# Optimize repository
restic -r rest:http://SERVER:8000/ prune
restic -r rest:http://SERVER:8000/ rebuild-index
```

## Best Practices

### Regular Maintenance

```bash
# Weekly: Check last backup
restic snapshots --latest 1

# Monthly: Verify repository integrity
restic check

# Quarterly: Test restore
restic restore latest --target /tmp/test-restore --path /home/user/important

# Yearly: Full data check
restic check --read-data
```

### Before Making System Changes

```bash
# Force immediate backup before major changes
sudo systemctl start restic-backups-default.service

# Wait for backup to complete
sudo systemctl status restic-backups-default.service

# Verify snapshot was created
restic snapshots --latest 1
```

### Recovery Testing

```bash
# 1. Create test file
echo "test" > /tmp/test-file.txt

# 2. Backup
sudo systemctl start restic-backups-default.service

# 3. Delete file
rm /tmp/test-file.txt

# 4. Restore
restic restore latest --target /tmp --path /tmp/test-file.txt

# 5. Verify
cat /tmp/tmp/test-file.txt
```

## Retention Policy Examples

```bash
# Keep 7 daily, 4 weekly, 12 monthly
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune

# Keep last 30 snapshots
restic forget --keep-last 30 --prune

# Keep one snapshot per hour for last 24 hours
restic forget --keep-hourly 24 --prune

# Keep everything for last 7 days, then weekly
restic forget --keep-within 7d --keep-weekly 52 --prune

# Custom retention
restic forget \
  --keep-within 3d \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --keep-yearly 5 \
  --prune
```

## Common Paths to Backup

### Desktop/Laptop
- `/home` - User data
- `/etc` - System configuration
- `/root` - Root user home
- `/opt` - Optional software

### Server
- `/home` - User data
- `/etc` - Configuration
- `/var/lib` - Application data
- `/srv` - Service data
- `/root` - Root home

### Common Exclusions
- `/var/cache` - Temporary cache
- `/var/tmp` - Temporary files
- `/var/log` - Log files
- `~/.cache` - User cache
- `~/.local/share/Trash` - Trash
- `*/node_modules` - NPM packages
- `*/.git` - Git repos (usually)
- `*/target` - Rust build dir
- `*/build` - Build directories

## Tips

1. **Always test restores** - A backup is only good if you can restore from it
2. **Monitor backup logs** - Check regularly for errors
3. **Keep multiple backup copies** - Follow 3-2-1 rule (3 copies, 2 media types, 1 offsite)
4. **Document your setup** - Write down passwords, procedures
5. **Use append-only mode** - Prevents ransomware from deleting backups
6. **Encrypt at rest** - Restic encrypts by default, but secure your password
7. **Test regularly** - Monthly integrity checks, quarterly restore tests
8. **Monitor disk space** - Ensure backup drive has enough space
9. **Version control configs** - Keep backup configs in git
10. **Automate monitoring** - Set up alerts for failed backups

## Emergency Recovery

### Lost Password

If you lose the repository password, **your backups are unrecoverable**. There is no password recovery mechanism. Always:
- Store password in multiple secure locations
- Use SOPS or similar secrets management
- Keep offline backup of password

### Corrupted Repository

```bash
# 1. Check what's wrong
restic check --read-data

# 2. Try to repair
restic repair index
restic repair snapshots

# 3. If fails, copy to new repository
restic copy --repo rest:http://SERVER:8000/ --repo2 rest:http://SERVER:8001/

# 4. Verify new repository
restic -r rest:http://SERVER:8001/ check
```

### Failed Disk

```bash
# 1. Stop restic server
sudo systemctl stop restic-rest-server.service

# 2. Try to recover data
sudo fsck /dev/sdX1

# 3. Mount disk read-only
sudo mount -o ro /dev/sdX1 /mnt/recovery

# 4. Copy data to new disk
sudo rsync -av /mnt/recovery/ /new/backups/

# 5. Update configuration with new disk
# 6. Verify repository
restic -r rest:http://127.0.0.1:8000/ check
```

