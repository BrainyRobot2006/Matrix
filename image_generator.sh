#!/bin/bash
# =========================================
# Matrix Morpheus GRUB Theme Generator
# Dynamically generates selection images
# supporting multiple OS entries.
# =========================================

THEME_DIR="$(dirname "$0")"
ICON_DIR="$THEME_DIR/os_icons"
OUTPUT_DIR="$THEME_DIR"
BASE_RED="$THEME_DIR/base_r.png"
BASE_BLUE="$THEME_DIR/base_b.png"
BASE_NONE="$THEME_DIR/base_n.png"

# Check ImageMagick
if ! command -v magick >/dev/null 2>&1; then
    echo "❌ ImageMagick (magick) not found! Please install it first."
    echo "   Example: sudo pacman -S imagemagick  or  sudo apt install imagemagick"
    exit 1
fi

echo "🔍 Detecting OS entries from GRUB..."

# --- Auto-detection (disabled for testing) ---
# mapfile -t entries < <(grep "menuentry " /boot/grub/grub.cfg | awk -F"'" '{print $2}')
# if [ ${#entries[@]} -eq 0 ]; then
#     echo "⚠️ No menu entries found! Aborting."
#     exit 1
# fi

# --- Manual test entries ---
entries=("Arch Linux" "Ubuntu" "Parrot" "Fedora" "Windows")

echo "Detected the following entries: "

for entry in "${entries[@]}"; do
    echo "$entry"
done

declare -A os_icon_map
declare -A os_color_map

# ============= OS DETECTION AND USER INPUT =============
for entry in "${entries[@]}"; do
    lower=$(echo "$entry" | tr '[:upper:]' '[:lower:]')
    default_icon="os_linux.png"

    case "$lower" in
        *arch*) default_icon="os_arch.png" ;;
        *ubuntu*) default_icon="os_ubuntu.png" ;;
        *fedora*) default_icon="os_fedora.png" ;;
        *manjaro*) default_icon="os_manjaro.png" ;;
        *debian*) default_icon="os_debian.png" ;;
        *mint*) default_icon="os_linuxmint.png" ;;
        *kali*) default_icon="os_kali.png" ;;
        *endeavour*) default_icon="os_endeavourOS.png" ;;
        *win*) default_icon="os_win.png" ;;
    esac

    echo ""
    echo "Detected OS: $entry"
    default_pill=$( [[ "$lower" == *win* ]] && echo "blue" || echo "red" )
    read -p "Is this a red pill or blue pill? [red/blue] (default: $default_pill): " pill
    pill=${pill:-$default_pill}

    read -p "Select icon file (default: $default_icon): " icon
    icon=${icon:-$default_icon}

    if [ ! -f "$ICON_DIR/$icon" ]; then
        echo "⚠️  Warning: $ICON_DIR/$icon not found. Using os_unknown.png."
        icon="os_unknown.png"
    fi

    os_icon_map["$entry"]="$icon"
    os_color_map["$entry"]="$pill"
done

# ============= VERIFICATION =============
echo ""
echo "🧾 Summary:"
for entry in "${!os_icon_map[@]}"; do
    echo "  - $entry → ${os_color_map[$entry]} pill → ${os_icon_map[$entry]}"
done

echo ""
read -p "Continue to generate themed images? [Y/n] " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ============= PREPARATION =============
TMP_DIR=$(mktemp -d)
#TMP_DIR=temp

# Normalize icons
echo ""
echo "🎨 Normalizing icons..."
for entry in "${!os_icon_map[@]}"; do
    icon="${os_icon_map[$entry]}"
    filename=$(basename "$icon")
    magick "$ICON_DIR/$icon" \
        -trim +repage \
        -resize 130x130 \
        -background none -gravity center \
        -extent 312x312 "$TMP_DIR/$filename"
done

# Additional function icons
for func in func_shutdown.png func_hidden.png func_firmware.png; do
    if [ -f "$ICON_DIR/$func" ]; then
        magick "$ICON_DIR/$func" \
            -trim +repage -resize 130x130 \
            -background none -gravity center \
            -extent 312x312 \
            -resize 50%  "$TMP_DIR/$func"
    fi
done

first_red=""
last_red=""
first_blue=""
last_blue=""

for entry in "${entries[@]}"; do
    pill="${os_color_map[$entry]}"

    if [[ "$pill" == "red" ]]; then
        [[ -z "$first_red" ]] && first_red="${os_icon_map[$entry]}"
        last_red="${os_icon_map[$entry]}"
    elif [[ "$pill" == "blue" ]]; then
        [[ -z "$first_blue" ]] && first_blue="${os_icon_map[$entry]}"
        last_blue="${os_icon_map[$entry]}"
    fi
done


echo "First red pill:  $first_red"
echo "Last red pill:   $last_red"
echo "First blue pill: $first_blue"
echo "Last blue pill:  $last_blue"

magick "$TMP_DIR/$first_blue" -resize 120% -fill "#00ebff" -colorize 100% "$TMP_DIR/first_blue.png"
magick "$TMP_DIR/$last_red" -resize 120% -fill "#FF0000" -colorize 100% "$TMP_DIR/last_red.png"

# ============= GENERATION =============
echo ""
echo "🧩 Generating composite images..."

for entry in "${!os_icon_map[@]}"; do
    pill="${os_color_map[$entry]}"
    icon="${os_icon_map[$entry]}"

    # Generate readable filename
    output_file="$OUTPUT_DIR/${entry,,}.png"
    output_file="${output_file// /_}"
    output_file="${output_file//[^a-z0-9_.-]/}"

    # Prepare scaled versions
    #magick "$TMP_DIR/$icon" -resize 120% "$TMP_DIR/base_${pill}.png"
    magick "$TMP_DIR/$icon" -resize 140% "$TMP_DIR/scaled_${pill}.png"

    if [ "$pill" == "red" ]; then
        #magick "$TMP_DIR/base_${pill}.png" -fill "#FF0000" -colorize 100% "$TMP_DIR/base_${pill}.png"
        magick "$TMP_DIR/scaled_${pill}.png" -fill "#FF0000" -colorize 100% "$TMP_DIR/scaled_${pill}.png"
        base_image="$BASE_RED"
        magick "$base_image" \
            "$TMP_DIR/scaled_red.png" -geometry +305+260 -composite \
            "$TMP_DIR/first_blue.png" -geometry +1210+345 -composite \
            "$TMP_DIR/scaled_red.png" -geometry +305+260 -composite \
            "$TMP_DIR/first_blue.png" -geometry +1210+345 -composite \
            "$TMP_DIR/func_firmware.png" -geometry +695+840 -composite \
            "$TMP_DIR/func_shutdown.png" -geometry +895+840 -composite \
            "$TMP_DIR/func_hidden.png" -geometry +1095+840 -composite \
            "$output_file"
    else
        #magick "$TMP_DIR/base_${pill}.png" -fill "#00ebff" -colorize 100% "$TMP_DIR/base_${pill}.png"
        magick "$TMP_DIR/scaled_${pill}.png" -fill "#00ebff" -colorize 100% "$TMP_DIR/scaled_${pill}.png"
        base_image="$BASE_BLUE"
        magick "$base_image" \
            "$TMP_DIR/scaled_blue.png" -geometry +1190+260 -composite \
            "$TMP_DIR/last_red.png" -geometry +335+345 -composite \
            "$TMP_DIR/scaled_blue.png" -geometry +1190+260 -composite \
            "$TMP_DIR/last_red.png" -geometry +335+345 -composite \
            "$TMP_DIR/func_firmware.png" -geometry +695+840 -composite \
            "$TMP_DIR/func_shutdown.png" -geometry +895+840 -composite \
            "$TMP_DIR/func_hidden.png" -geometry +1095+840 -composite \
            "$output_file"
    fi

    echo "✅ Created: $(basename "$output_file")"
done

# ============= CLEANUP =============
rm -rf "$TMP_DIR"

echo ""
echo "🎉 All images generated successfully in $OUTPUT_DIR!"
