#!/bin/bash
set -euo pipefail  

BACKUP_ROOT="/var/backups/matrix-grub"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_ROOT/matrix-grub-backup-$TIMESTAMP.tar.gz"

GRUB_DEFAULT="/etc/default/grub"
GRUB_CFG="/boot/grub/grub.cfg"
GRUB_D="/etc/grub.d"

usage() {
    echo "Usage:"
    echo "  sudo $0 backup   # Backup GRUB-related files"
    echo "  sudo $0 restore  # Restore latest backup"
    exit 1
}

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

mkdir -p "$BACKUP_ROOT"

if [[ -f /boot/grub2/grub.cfg ]]; then
       GRUB_CFG="/boot/grub2/grub.cfg"
   elif [[ -f /boot/grub/grub.cfg ]]; then
       GRUB_CFG="/boot/grub/grub.cfg"
   else
       echo "Could not locate grub.cfg"
       exit 1
   fi

if [[ $# -eq 0 ]]; then
    usage
fi

case "$1" in
    backup)
        echo "Backing up GRUB configuration..."

        tar -czpf "$BACKUP_FILE" \
            "$GRUB_DEFAULT" \
            "$GRUB_CFG" \
            "$GRUB_D"

        echo "Backup created:"
        echo "   $BACKUP_FILE"
        ;;

    restore)
        echo "Restoring GRUB configuration..."

        LATEST_BACKUP=$(ls -t "$BACKUP_ROOT"/matrix-grub-backup-*.tar.gz 2>/dev/null | head -n 1)

        if [[ -z "$LATEST_BACKUP" ]]; then
            echo "No backup found."
            exit 1
        fi

        echo "Warning! This will overwrite current GRUB configuration."
        read -rp "Continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Restore aborted."
            exit 0
        fi

        tar -xzpf "$LATEST_BACKUP" -C /

        echo "Regenerating GRUB..."
        if command -v grub-mkconfig >/dev/null; then
            grub-mkconfig -o "$GRUB_CFG"
        else
            echo "grub-mkconfig not found. Regenerate manually."
        fi

        echo "Restore complete."
        ;;

    *)
        usage
        ;;
esac
