#!/bin/bash

# Path to the cwebp binary (Apple Silicon default)
WEBP="/opt/homebrew/bin/cwebp"

# 1. Ask user for quality preference
CHOICE=$(osascript <<EOT
    set theResponse to button returned of (display dialog "Choose WebP quality:" buttons {"Low (60)", "Medium (80)", "High (98)"} default button "Medium (80)")
    return theResponse
EOT
)

# Exit if user cancels
if [ -z "$CHOICE" ]; then exit 1; fi

# 2. Map choice to numeric quality value
case "$CHOICE" in
    "Low (60)")
        Q_VAL=60
        ;;
    "Medium (80)")
        Q_VAL=80
        ;;
    "High (98)")
        Q_VAL=98
        ;;
esac

# 3. Process each selected file
for f in "$@"; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    filename="${base%.*}"
    output="$dir/$filename.webp"

    # Execute conversion with max compression effort (-m 6)
    "$WEBP" -q "$Q_VAL" -m 6 "$f" -o "$output"
done

osascript -e "display notification \"Converted images at $CHOICE quality.\" with title \"WebP Conversion Complete\""