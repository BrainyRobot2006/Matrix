#!/bin/bash
# ===============================================================
# Matrix Morpheus GRUB Theme Installer
# Repository: https://github.com/Priyank-Adhav/Matrix-GRUB-Theme
# ===============================================================

set -e

THEME_NAME="Matrix"
THEME_DIR="/boot/grub/themes"
GRUB_CFG="/etc/default/grub"
GRUB_FILE="/boot/grub/grub.cfg"

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

echo ""

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

# Copy theme files 
echo "Installing theme..."
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
