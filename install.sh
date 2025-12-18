#!/bin/bash
# ===============================================================
# Matrix Morpheus GRUB Theme Installer
# Repository: https://github.com/Priyank-Adhav/Matrix-GRUB-Theme
# ===============================================================

set -euo pipefail 

THEME_NAME="Matrix"
THEME_DIR="/boot/grub/themes"
GRUB_CFG="/etc/default/grub"
GRUB_FILE=""
THEME_FILE="./Matrix/theme.txt"

echo ""
echo "==========================="
echo "Matrix GRUB Theme Installer"
echo "==========================="
echo ""

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Backup existing GRUB configuration
if [[ -x "./backup.sh" ]]; then
    echo "Backing up existing GRUB configuration..."
    ./backup.sh backup
else
    echo "backup.sh not found or not executable."
    exit 1
fi

if [[ -f /boot/grub2/grub.cfg ]]; then
       GRUB_FILE="/boot/grub2/grub.cfg"
   elif [[ -f /boot/grub/grub.cfg ]]; then
       GRUB_FILE="/boot/grub/grub.cfg"
   else
       echo "Could not locate grub.cfg"
       exit 1
   fi

echo ""

echo "== Display resolution configuration =="

# Try to read GRUB_GFXMODE
GFXMODE=$(grep -E '^GRUB_GFXMODE=' /etc/default/grub 2>/dev/null \
          | cut -d= -f2 | tr -d '"')

if [[ "$GFXMODE" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    detected_width="${BASH_REMATCH[1]}"
    detected_height="${BASH_REMATCH[2]}"
    echo "Detected GRUB resolution: ${detected_width}x${detected_height}"
else
    detected_width=""
    detected_height=""
    echo "GRUB resolution not detected."
fi

if [[ -n "$detected_width" ]]; then
    read -r -p "Use detected resolution? [Y/n]: " reply
    if [[ "$reply" =~ ^[Nn]$ ]]; then
        detected_width=""
        detected_height=""
    fi
fi

DEFAULT_WIDTH=1920
DEFAULT_HEIGHT=1080

# Manual entry if needed
while [[ -z "$detected_width" ]]; do
    read -r -p "Enter GRUB resolution [Default: ${DEFAULT_WIDTH}x${DEFAULT_HEIGHT}]: " input

    if [[ -z "$input" ]]; then
        detected_width="$DEFAULT_WIDTH"
        detected_height="$DEFAULT_HEIGHT"
        break
    fi

    if [[ "$input" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        detected_width="${BASH_REMATCH[1]}"
        detected_height="${BASH_REMATCH[2]}"
    else
        echo "Invalid format. Please use WIDTHxHEIGHT."
    fi
done

echo "Using resolution: ${detected_width}x${detected_height}"

echo "Updating theme layout..."

awk -v w="$detected_width" -v h="$detected_height" '
    BEGIN { in_menu=0; done=0 }
    {
        if ($0 ~ /^\+ boot_menu/ && !done) {
            in_menu=1
        }

        if (in_menu && !done) {
            if ($0 ~ /icon_width *=/)  { sub(/=.*/, "= " w) }
            if ($0 ~ /icon_height *=/) { sub(/=.*/, "= " h) }
            if ($0 ~ /item_height *=/) { sub(/=.*/, "= " h) }
        }

        print

        if (in_menu && $0 ~ /^\}/ && !done) {
            in_menu=0
            done=1
        }
    }
' "$THEME_FILE" > "${THEME_FILE}.tmp"

mv "${THEME_FILE}.tmp" "$THEME_FILE"

# Generate theme images
if [[ -x "./image_generator.sh" ]]; then
    echo "Generating theme images..."
    ./image_generator.sh
else
    echo "image_generator.sh not found or not executable."
    exit 1
fi

echo ""

# Ensure theme directory exists 
mkdir -p "$THEME_DIR"

DEST="$THEME_DIR/$THEME_NAME"

if [[ -d "$DEST" ]]; then
    echo "Existing theme found. Replacing it."
    rm -rf "$DEST"
fi

cp -r "$THEME_NAME" "$THEME_DIR/" || {
    echo "Failed to copy theme files."
    exit 1
}


# Configure GRUB to use the new theme 
echo "Updating GRUB configuration..."
if grep -q '^GRUB_THEME=' "$GRUB_CFG"; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"|" "$GRUB_CFG"
else
    echo "" >> "$GRUB_CFG"
    echo "GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"" >> "$GRUB_CFG"
fi

# Regenerate GRUB
echo "Rebuilding GRUB configuration..."
if command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o "$GRUB_FILE" >/dev/null
    echo "GRUB configuration updated successfully."
else
    echo "grub-mkconfig not found. Please update your GRUB manually."
    exit 1
fi

echo ""
echo "Installation complete!"
echo "Reboot to see your new Matrix GRUB theme."
echo ""
