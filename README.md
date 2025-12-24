# macOS Convert to WebP Quick Action

A lightweight Finder Quick Action for macOS that allows you to select one or more images (JPG, PNG, etc.) and convert them to the WebP format. The converted file is saved in the same directory as the original, using the `webp` file extension.

## Features
- **In-place conversion:** No need to move files or open apps.
- **Batch processing:** Select multiple images and convert them all at once.
- **Quality Presets:** Choose between Low (60), Medium (80), or High (98) quality.
- **Universal:** Works on both Intel and Apple Silicon Macs.

## Prerequisites

This action requires the `webp` (cwebp) utility installed via Homebrew.

1. **Install Homebrew** (if not already installed):
   `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

2. **Install WebP**:
   `brew install webp`

## Installation

### Option A: The Easy Way (Recommended)
1. Download the `Convert to WebP.workflow.zip` from this repository.
2. Unzip the file.
3. Double-click the `Convert to WebP.workflow` file.
4. macOS will ask if you want to install it. Click **Install**.

### Option B: Manual Setup (Build it yourself)
1. Open **Automator** on your Mac.
2. Choose **File > New** -> **Quick Action**.
3. Set "Workflow receives current" to **image files** in **Finder**.
4. Search for "Run Shell Script" in the library and drag it into the workflow.
5. Set **Shell** to `/bin/bash` and **Pass input** to **as arguments**.
6. Paste the following code into the script box:

```bash
#!/bin/bash

# Path to the cwebp binary
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

    # Execute conversion
    "$WEBP" -q "$Q_VAL" -m 6 "$f" -o "$output"
done

osascript -e "display notification \"Converted images at $CHOICE quality.\" with title \"WebP Conversion Complete\""
```

7. Save the workflow (Cmd + S) as `Convert to WebP`.

## Usage
1. Open **Finder** and select one or more images.
2. Right-click and navigate to **Quick Actions > Convert to WebP**.
3. Choose your desired quality from the popup dialog.

## Troubleshooting
- **Permission Denied:** If the script fails silently, ensure Automator has "Full Disk Access" in **System Settings > Privacy & Security**.
- **Path Error:** This script looks for `cwebp` at `/opt/homebrew/bin/cwebp`. If you are on an older Intel Mac, you may need to update the path in the script to `/usr/local/bin/cwebp`.

## License
Distributed under the MIT License. Enjoy.