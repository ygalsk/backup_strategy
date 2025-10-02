# Borg Backup Setup Guide

Quick setup guide for automated backups to Hetzner Storage Box using BorgBackup.

## Prerequisites

```bash
sudo apt install borgbackup
```

## 1. SSH Key Setup

Generate and copy SSH key to Hetzner Storage Box:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/hetzner-backup -N ""
ssh-copy-id -i ~/.ssh/hetzner-backup.pub -p 23 <username>@<username>.your-storagebox.de
```

Test connection:
```bash
ssh -i ~/.ssh/hetzner-backup -p 23 <username>@<username>.your-storagebox.de
```

## 2. SSH Config

Create `~/.ssh/config`:

```
Host hetzner-backup
    HostName <username>.your-storagebox.de
    Port 23
    User <username>
    IdentityFile ~/.ssh/hetzner-backup
```

## 3. Create Backup Directory on Hetzner

```bash
ssh hetzner-backup
mkdir -p /home/backups
exit
```

## 4. Setup Script

Place `backup.sh` in `/opt/deployment_configs/` and make executable:

```bash
chmod +x /opt/deployment_configs/backup.sh
```

Create log directory:
```bash
sudo mkdir -p /opt/alles/log
sudo chown $USER:$USER /opt/alles/log
```

## Running Backups

### Option A: Without sudo (Recommended)

Add your user to the docker group and set permissions:
```bash
sudo usermod -aG docker $USER
sudo chgrp -R docker /opt/alles/soda4lca
sudo chmod -R g+rX /opt/alles/soda4lca
```

Log out and back in, then verify:
```bash
groups  # Should show 'docker'
```

Run backup:
```bash
./backup.sh
```

Setup cron (runs daily at 2 AM):
```bash
crontab -e
# Add: 0 2 * * * /opt/deployment_configs/backup.sh >> /opt/alles/log/borg-backup-cron.log 2>&1
```

### Option B: With sudo

Copy SSH config to root:
```bash
sudo mkdir -p /root/.ssh
sudo cp ~/.ssh/hetzner-backup /root/.ssh/
sudo tee -a /root/.ssh/config > /dev/null << 'EOF'
Host hetzner-backup
    HostName <username>.your-storagebox.de
    Port 23
    User <username>
    IdentityFile /root/.ssh/hetzner-backup
EOF
sudo chmod 600 /root/.ssh/hetzner-backup /root/.ssh/config
```

Run backup:
```bash
sudo ./backup.sh
```

Setup cron:
```bash
sudo crontab -e
# Add: 0 2 * * * /opt/deployment_configs/backup.sh >> /opt/alles/log/borg-backup-cron.log 2>&1
```

## Monitoring

View logs:
```bash
tail -f /opt/alles/log/borg-backup.log
```

List backups:
```bash
borg list ssh://hetzner-backup/home/backups/<directory_name>
```

## Restoring

Extract backup:
```bash
borg extract ssh://hetzner-backup/home/backups/<directory_name>::<archive_name>
```

Mount and browse:
```bash
mkdir /tmp/borg-mount
borg mount ssh://hetzner-backup/home/backups/<directory_name>::<archive_name> /tmp/borg-mount
# Browse files, then:
borg umount /tmp/borg-mount
```

## Retention Policy

- 7 daily backups
- 4 weekly backups  
- 6 monthly backups

## Notes

Script backs up all `datafiles/` directories found under `/opt/alles/soda4lca`.
Each directory gets its own Borg repository on Hetzner.