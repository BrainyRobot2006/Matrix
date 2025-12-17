#!/bin/bash

THEME_DIR="$(dirname "$0")"
ICON_DIR="$THEME_DIR/os_icons"
OUTPUT_DIR="$THEME_DIR/Matrix/icons"
BASE_RED="$THEME_DIR/base/base_r.png"
BASE_BLUE="$THEME_DIR/base/base_b.png"
BASE_NONE="$THEME_DIR/base/base_n.png"

# Check ImageMagick
if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick (magick) not found! Please install it first."
    echo "   Example: sudo pacman -S imagemagick  or  sudo apt install imagemagick"
    exit 1
fi

echo "Detecting OS entries from GRUB..."

# Menuentry detection
mapfile -t entries < <(
  awk '
    $1 == "menuentry" || $2 == "menuentry" {
      for (i = 1; i <= NF; i++) {
        if ($i == "--class") {
          print $(i+1)
          break
        }
      }
    }
  ' /boot/grub/grub.cfg
)


if [ ${#entries[@]} -eq 0 ]; then
    echo "⚠️ No menu entries found! Aborting."
    exit 1
fi

# Manual test entries
#entries=("Arch" "Windows" "func1" "func2" "func3" "func4")

echo "Detected the following entries: "

for entry in "${entries[@]}"; do
    echo "$entry"
done

declare -A os_icon_map
declare -A function_icon_map
function_entries=()
declare -A os_color_map

# OS DETECTION AND USER INPUT
for entry in "${entries[@]}"; do
    lower=$(echo "$entry" | tr '[:upper:]' '[:lower:]')
    default_icon="os_linux.png"

    case "$lower" in
        *arch*) default_icon="arch.png" ;;
        *ubuntu*) default_icon="ubuntu.png" ;;
        *fedora*) default_icon="fedora.png" ;;
        *manjaro*) default_icon="manjaro.png" ;;
        *debian*) default_icon="debian.png" ;;
        *mint*) default_icon="linuxmint.png" ;;
        *kali*) default_icon="kali.png" ;;
        *endeavour*) default_icon="endeavourOS.png" ;;
        *win*) default_icon="win.png" ;;
        *func*) default_icon="func_firmware.png" ;;
    esac

    echo ""
    echo "Detected OS: $entry"

    if [[ "$default_icon" == "func_firmware.png" ]]; then
        default_pill="function"
    elif [[ "$lower" == *win* ]]; then
        default_pill="blue"
    else
        default_pill="red"
    fi

    # Select pill  type
    pill_options=(red blue function)

    echo "Select pill type (default: $default_pill):"
    for i in "${!pill_options[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${pill_options[i]}"
    done

    read -r -p "> " reply

    if [[ -z "$reply" ]]; then
        pill="$default_pill"
    elif [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#pill_options[@]} )); then
        pill="${pill_options[reply-1]}"
    else
        echo "Invalid selection. Using default."
        pill="$default_pill"
    fi

    echo "Selected pill: $pill"
    echo ""

    # Select icon
    available_icons=()
    while IFS= read -r f; do
        available_icons+=( "$(basename "$f")" )
    done < <(find "$ICON_DIR" -maxdepth 1 -type f -name '*.png' | sort)

    echo "Select icon file (default: $default_icon):"
    echo "Available icons:"

    items=()
    for i in "${!available_icons[@]}"; do
        items+=( "$((i+1))) ${available_icons[i]}" )
    done
    items+=( "$(( ${#available_icons[@]} + 1 ))) Use default" )
    printf "%s\n" "${items[@]}" | column

    read -r -p "> " reply

    # Enter → default
    if [[ -z "$reply" ]]; then
        icon="$default_icon"
    elif [[ "$reply" =~ ^[0-9]+$ ]]; then
        if (( reply >= 1 && reply <= ${#available_icons[@]} )); then
            icon="${available_icons[reply-1]}"
        elif (( reply == ${#available_icons[@]} + 1 )); then
            icon="$default_icon"
        else
            echo "Invalid selection. Using default."
            icon="$default_icon"
        fi
    else
        echo "Invalid input. Using default."
        icon="$default_icon"
    fi

    echo "Selected icon: $icon"

    if [ ! -f "$ICON_DIR/$icon" ]; then
        echo "⚠️  Warning: $ICON_DIR/$icon not found. Using os_unknown.png."
        icon="os_unknown.png"
    fi

    if [[ "$pill" == function ]]; then
        function_icon_map["$entry"]="$icon"
        function_entries+=( "$entry" )
    else
        os_icon_map["$entry"]="$icon"
        os_color_map["$entry"]="$pill"
    fi
done

# VERIFICATION
echo ""
echo "Summary:"
for entry in "${!os_icon_map[@]}"; do
    echo "  - $entry → ${os_color_map[$entry]} pill → ${os_icon_map[$entry]}"
done

for entry in "${!function_icon_map[@]}"; do
    echo "  - $entry →  function → ${function_icon_map[$entry]}"
done

echo ""
read -p "Continue to generate themed images? [Y/n] " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# PREPARATION 
TMP_DIR=$(mktemp -d)
#TMP_DIR=temp

# Normalize icons
echo ""
echo "Normalizing icons..."
for entry in "${!os_icon_map[@]}"; do
    icon="${os_icon_map[$entry]}"
    filename=$(basename "$icon")
    magick "$ICON_DIR/$icon" \
        -trim +repage \
        -resize 130x130 \
        -background none -gravity center \
        -extent 312x312 \
        "$TMP_DIR/$filename"
done

for entry in "${!function_icon_map[@]}"; do
    icon="${function_icon_map[$entry]}"
    filename=$(basename "$icon")

    magick "$ICON_DIR/$icon" \
        -trim +repage \
        -resize 130x130 \
        -background none -gravity center \
        -extent 312x312 \
        -fill "#8f8f8f" \
        -colorize 100% \
        -resize 50% \
        "$TMP_DIR/$filename"
done

magick "$ICON_DIR/selection.png" \
    -trim +repage \
    -resize 130x130 \
    -background none -gravity center \
    -resize 150% \
    -extent 312x312 "$TMP_DIR/selection.png"

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


magick "$TMP_DIR/$first_blue" -resize 120% -fill "#00ebff" -colorize 100% "$TMP_DIR/first_blue.png"
magick "$TMP_DIR/$last_blue" -resize 120% -fill "#00ebff" -colorize 100% "$TMP_DIR/last_blue.png"
magick "$TMP_DIR/$first_red" -resize 120% -fill "#FF0000" -colorize 100% "$TMP_DIR/first_red.png"
magick "$TMP_DIR/$last_red" -resize 120% -fill "#FF0000" -colorize 100% "$TMP_DIR/last_red.png"

# GENERATION 
echo ""
echo "Generating composite images..."

# Generate function row 
num_elements=${#function_icon_map[@]}
if (( num_elements % 2 == 0 )); then
    x_cord=$(( 995 - (num_elements) * 100 ))
else
    x_cord=$(( 895 - (num_elements - 1) * 100 ))
fi

for entry in "${!os_icon_map[@]}"; do
    pill="${os_color_map[$entry]}"
    icon="${os_icon_map[$entry]}"
    class_name="${entries[$entry]}"

    # Generate readable filename
    filename="${entry,,}.png"
    filename="${filename// /_}"
    filename="${filename//[^a-z0-9_.-]/}"
    output_file="$OUTPUT_DIR/$filename"

    # Prepare scaled versions
    magick "$TMP_DIR/$icon" -resize 140% "$TMP_DIR/scaled_${pill}.png"

    if [ "$pill" == "red" ]; then
        magick "$TMP_DIR/scaled_${pill}.png" -fill "#FF0000" -colorize 100% "$TMP_DIR/scaled_${pill}.png"
        base_image="$BASE_RED"
        args=(
            "$base_image"
            "$TMP_DIR/scaled_red.png" -geometry +305+260 -composite
            "$TMP_DIR/first_blue.png" -geometry +1210+345 -composite
            "$TMP_DIR/scaled_red.png" -geometry +305+260 -composite
            "$TMP_DIR/first_blue.png" -geometry +1210+345 -composite
        )
        temp_x_cord=$((x_cord))
        for f_entry in "${!function_icon_map[@]}"; do
            icon="${function_icon_map[$f_entry]}"
            args+=( "$TMP_DIR/$icon" -geometry +${temp_x_cord}+840 -composite )
            args+=( "$TMP_DIR/$icon" -geometry +${temp_x_cord}+840 -composite )
            ((temp_x_cord+=200))
        done

        magick "${args[@]}" "$output_file"
    
    elif [ "$pill" == "blue" ]; then
        magick "$TMP_DIR/scaled_${pill}.png" -fill "#00ebff" -colorize 100% "$TMP_DIR/scaled_${pill}.png"
        base_image="$BASE_BLUE"
        args=(
            "$base_image"
            "$TMP_DIR/scaled_blue.png" -geometry +1190+260 -composite
            "$TMP_DIR/last_red.png" -geometry +335+345 -composite
            "$TMP_DIR/scaled_blue.png" -geometry +1190+260 -composite
            "$TMP_DIR/last_red.png" -geometry +335+345 -composite
        )
        temp_x_cord=$((x_cord))
        for f_entry in "${function_entries[@]}"; do
            icon="${function_icon_map[$f_entry]}"
            args+=( "$TMP_DIR/$icon" -geometry +${temp_x_cord}+840 -composite )
            args+=( "$TMP_DIR/$icon" -geometry +${temp_x_cord}+840 -composite )
            ((temp_x_cord+=200))
        done

        magick "${args[@]}" "$output_file"
    fi

    echo "Created: $(basename "$output_file")"
done

temp_x_cord=$((x_cord))
for entry in "${function_entries[@]}"; do
    icon="${function_icon_map[$entry]}"
    # Generate readable filename
    filename="${entry,,}.png"
    filename="${filename// /_}"
    filename="${filename//[^a-z0-9_.-]/}"
    output_file="$OUTPUT_DIR/$filename"

    base_image="$BASE_NONE"
    args=(
        "$base_image"
        "$TMP_DIR/last_red.png" -geometry +335+345 -composite
        "$TMP_DIR/first_blue.png" -geometry +1210+345 -composite
        "$TMP_DIR/last_red.png" -geometry +335+345 -composite
        "$TMP_DIR/first_blue.png" -geometry +1210+345 -composite
        "$TMP_DIR/selection.png" -geometry +$((temp_x_cord - 80))+760 -composite
    )
    ((temp_x_cord+=200))
    temp2_x_cord=$((x_cord))
    for f_entry in "${function_entries[@]}"; do
        icon="${function_icon_map[$f_entry]}"
        args+=( "$TMP_DIR/$icon" -geometry +${temp2_x_cord}+840 -composite )
        args+=( "$TMP_DIR/$icon" -geometry +${temp2_x_cord}+840 -composite )
        ((temp2_x_cord+=200))
    done

    magick "${args[@]}" "$output_file"
    echo "Created: $(basename "$output_file")"
done

# CLEANUP
rm -rf "$TMP_DIR"

echo ""
echo "All images generated successfully in $OUTPUT_DIR"
