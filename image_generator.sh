#!/bin/bash

THEME_DIR="$(dirname "$0")"
ICON_DIR="$THEME_DIR/os_icons"
OUTPUT_DIR="$THEME_DIR"
BASE_RED="$THEME_DIR/base_r.png"
BASE_BLUE="$THEME_DIR/base_b.png"

if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick (magick) not found! Please install it first."
    echo "   For example: sudo pacman -S imagemagick  or  sudo apt install imagemagick"
    exit 1
fi

# detect os menuentries
echo "Detecting OS entries from GRUB..."
entries=($(grep "menuentry " /boot/grub/grub.cfg | awk -F"'" '{print $2}'))

if [ ${#entries[@]} -eq 0 ]; then
    echo "No menu entries found! Aborting."
    exit 1
fi

# auto-detect red pill icon
red_pill_icon=""
for entry in "${entries[@]}"; do
    case "${entry,,}" in
        *arch*) red_pill_icon="os_arch.png" ;;
        *ubuntu*) red_pill_icon="os_ubuntu.png" ;;
        *fedora*) red_pill_icon="os_fedora.png" ;;
        *manjaro*) red_pill_icon="os_manjaro.png" ;;
        *debian*) red_pill_icon="os_debian.png" ;;
        *mint*) red_pill_icon="os_linuxmint.png" ;;
        *kali*) red_pill_icon="os_kali.png" ;;
        *endeavour*) red_pill_icon="os_endeavourOS.png" ;;
    esac
    if [ -n "$red_pill_icon" ]; then break; fi
done

# fallback to default linux icon
if [ -z "$red_pill_icon" ]; then
    red_pill_icon="os_linux.png"
fi
blue_pill_icon="os_win.png"

echo ""
echo "Verification:"
echo "  Red pill OS detected: ${red_pill_icon}"
echo "  Blue pill OS fixed as: ${blue_pill_icon}"

if [ ! -f "$ICON_DIR/$red_pill_icon" ]; then
    echo "Missing red pill icon: $ICON_DIR/$red_pill_icon"
    exit 1
fi

if [ ! -f "$ICON_DIR/$blue_pill_icon" ]; then
    echo "Missing blue pill icon: $ICON_DIR/$blue_pill_icon"
    exit 1
fi

if [ ! -f "$BASE_RED" ] || [ ! -f "$BASE_BLUE" ]; then
    echo "Missing base images ($BASE_RED / $BASE_BLUE)"
    exit 1
fi

echo ""
read -p "Continue to generate selection images? [Y/n] " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

TMP_DIR=$(mktemp -d)

# Resize the icons
magick "$ICON_DIR/os_antergos.png" -resize 120% "$TMP_DIR/$red_pill_icon"
magick "$ICON_DIR/$blue_pill_icon" -resize 120% "$TMP_DIR/$blue_pill_icon"
magick "$ICON_DIR/os_antergos.png" -resize 140% "$TMP_DIR/red_scaled.png"
magick "$ICON_DIR/$blue_pill_icon" -resize 140% "$TMP_DIR/blue_scaled.png"
magick "$ICON_DIR/func_shutdown.png" -resize 200% "$TMP_DIR/func_shutdown.png"

# Recolor the icons
magick "$TMP_DIR/$red_pill_icon" -fill "#FF0000" -colorize 100% "$TMP_DIR/$red_pill_icon"
magick "$TMP_DIR/$blue_pill_icon" -fill "#00ebff" -colorize 100% "$TMP_DIR/$blue_pill_icon"
magick  "$TMP_DIR/red_scaled.png" -fill "#FF0000" -colorize 100% "$TMP_DIR/red_scaled.png"
magick "$TMP_DIR/blue_scaled.png"  -fill "#00ebff" -colorize 100% "$TMP_DIR/blue_scaled.png" 
magick  "$TMP_DIR/func_shutdown.png" -fill "#f0f0f0" -colorize 100% "$TMP_DIR/func_shutdown.png"

# Blue pill selected
#  Overlay icons twice to reduce transparency (could simplify this later)
magick "$BASE_BLUE" \
    "$TMP_DIR/blue_scaled.png" -geometry +1190+260 -composite \
    "$TMP_DIR/blue_scaled.png" -geometry +1190+260 -composite \
    "$TMP_DIR/$red_pill_icon" -geometry +335+360 -composite \
    "$TMP_DIR/$red_pill_icon" -geometry +335+360 -composite \
    "$TMP_DIR/func_shutdown.png" -geometry +940+840 -composite \
    "$OUTPUT_DIR/selection_1.png"

# Red pill selected
magick "$BASE_RED" \
    "$TMP_DIR/$blue_pill_icon" -geometry +1220+340 -composite \
    "$TMP_DIR/$blue_pill_icon" -geometry +1220+340 -composite \
    "$TMP_DIR/red_scaled.png" -geometry +305+245 -composite \
    "$TMP_DIR/red_scaled.png" -geometry +305+245 -composite \
    "$OUTPUT_DIR/selection_0.png"

# Clean up the temporary dir
rm -rf "$TMP_DIR"

echo ""
echo "  Created:"
echo "   - $OUTPUT_DIR/selection_0.png (Red Pill: Linux highlighted + enlarged)"
echo "   - $OUTPUT_DIR/selection_1.png (Blue Pill: Windows highlighted + enlarged)"
