# macOS Convert to WebP Quick Action

A professional-grade Finder Quick Action for macOS that converts images (JPG, PNG, etc.) to the WebP format. This tool is specifically designed to preserve critical file metadata, including **Creation Dates**, **Modification Dates**, and **Internal EXIF/GPS data**.

## Features
- **Finder Integration:** Convert files via the right-click "Quick Actions" menu.
- **Deep Metadata Sync:** Optionally maintains the "Date Created" (Birthtime) and "Content Created" timestamps.
- **Lean Mode:** Toggle metadata off for ultra-stripped, web-optimized files.
- **Batch Conversion:** Handle multiple files simultaneously.
- **Cleanup:** Option to auto-delete original files upon successful conversion.

## Prerequisites

To handle deep-syncing of dates and EXIF data, the following tools are required:

1. **WebP (cwebp):** `brew install webp`
2. **Exiftool:** `brew install exiftool`
3. **Xcode Command Line Tools:** Run `xcode-select --install` in Terminal (required for the `SetFile` command).

## Installation

1. Open **Automator** and create a new **Quick Action**.
2. Set "Workflow receives current" to **image files** in **Finder**.
3. Add a **Run Shell Script** action.
4. Set **Shell** to `/bin/bash` and **Pass input** to **as arguments**.
5. Paste the code below:

```bash
#!/bin/bash

# --- CONFIGURATION ---
WEBP="/opt/homebrew/bin/cwebp"
# Note: Ensure this path matches your 'which exiftool' output
EXIFTOOL="/opt/homebrew/bin/exiftool"

# --- 1. UI GENERATION (SWIFT) ---
read -r -d '' SWIFT_UI <<'EOF'
import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let alert = NSAlert()
alert.messageText = "WebP Conversion"
alert.informativeText = "Choose your compression and metadata preferences."
alert.addButton(withTitle: "Compress")
alert.addButton(withTitle: "Cancel")

let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 25))
popUp.addItems(withTitles: ["Low (60)", "Medium (80)", "High (98)"])
popUp.selectItem(at: 1)

// Checkbox: Delete Source
let checkDelete = NSButton(checkboxWithTitle: "Delete source files after processing", target: nil, action: nil)
checkDelete.frame = NSRect(x: 0, y: 0, width: 240, height: 25)

// Checkbox: Retain Metadata (Checked by default)
let checkMeta = NSButton(checkboxWithTitle: "Retain Metadata (EXIF, Dates, GPS)", target: nil, action: nil)
checkMeta.state = .on
checkMeta.frame = NSRect(x: 0, y: 0, width: 240, height: 25)

let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 250, height: 100))
stack.orientation = .vertical
stack.alignment = .leading
stack.spacing = 10
stack.addView(popUp, in: .top)
stack.addView(checkMeta, in: .top)
stack.addView(checkDelete, in: .top)

alert.accessoryView = stack
app.activate(ignoringOtherApps: true)

let response = alert.runModal()
if response == .alertFirstButtonReturn {
    let quality = popUp.titleOfSelectedItem ?? "Medium (80)"
    let deleteState = (checkDelete.state == .on) ? "YES" : "NO"
    let metaState = (checkMeta.state == .on) ? "YES" : "NO"
    print("\(quality)|\(deleteState)|\(metaState)")
} else {
    print("CANCEL")
}
EOF

RESULT=$(swift -e "$SWIFT_UI")

# --- 2. PARSE RESULTS ---
if [ "$RESULT" = "CANCEL" ] || [ -z "$RESULT" ]; then exit 0; fi

CHOICE=$(echo "$RESULT" | cut -d "|" -f 1)
DELETE_FLAG=$(echo "$RESULT" | cut -d "|" -f 2)
META_FLAG=$(echo "$RESULT" | cut -d "|" -f 3)

case "$CHOICE" in
    "Low (60)") Q_VAL=60 ;;
    "Medium (80)") Q_VAL=80 ;;
    "High (98)") Q_VAL=98 ;;
    *) Q_VAL=80 ;;
esac

# --- 3. PROCESSING ---
count=0

for f in "$@"; do
    [ -e "$f" ] || continue
    output="${f%.*}.webp"

    if [ "$META_FLAG" = "YES" ]; then
        # Capture dates from source
        creationDate=$(GetFileInfo -d "$f")
        modDate=$(GetFileInfo -m "$f")
        touchDate=$(stat -f "%Sm" -t "%Y%m%d%H%M.%S" "$f")

        # Convert WITH metadata
        "$WEBP" -q "$Q_VAL" -m 6 -metadata all "$f" -o "$output"

        if [ $? -eq 0 ]; then
            ((count++))
            # Copy EXIF
            if command -v "$EXIFTOOL" &> /dev/null; then
                "$EXIFTOOL" -tagsFromFile "$f" "-all:all>all:all" -overwrite_original "$output"
            fi
            # Set FileSystem Dates
            SetFile -d "$creationDate" "$output"
            SetFile -m "$modDate" "$output"
            touch -t "$touchDate" "$output"
        fi
    else
        # Convert WITHOUT metadata (Lean)
        "$WEBP" -q "$Q_VAL" -m 6 -metadata none "$f" -o "$output"
        if [ $? -eq 0 ]; then ((count++)); fi
    fi

    # Cleanup
    if [ "$DELETE_FLAG" = "YES" ] && [ -e "$output" ]; then
        rm "$f"
    fi
done

osascript -e "display notification \"Processed $count images. Metadata: $META_FLAG\" with title \"Success\""
```

6. Save the workflow (Cmd + S) as `Convert to WebP`.

## Usage
1. Open **Finder** and select one or more images.
2. Right-click and navigate to **Quick Actions > Convert to WebP**.
3. Choose your desired quality from the popup dialog.

## Troubleshooting
- **Permission Denied:** If the script fails silently, ensure Automator has "Full Disk Access" in **System Settings > Privacy & Security**.
- **Path Error:** This script looks for `cwebp` at `/opt/homebrew/bin/cwebp`. If you are on an older Intel Mac, you may need to update the path in the script to `/usr/local/bin/cwebp`.

## License
Distributed under the MIT License. Enjoy.
