# macOS Convert to WebP Quick Action

A lightweight Finder Quick Action for macOS that allows you to select one or more images (JPG, PNG, etc.) and convert them to the WebP format. It features a native UI to select quality and optionally delete the original files.

## Features
- **In-place conversion:** No need to open apps; works directly in Finder.
- **Batch processing:** Select multiple images and convert them all at once.
- **Quality Control:** Dropdown selection for Low (60), Medium (80), or High (98) quality.
- **Cleanup Option:** Optional checkbox to automatically delete source files after successful conversion.
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

# --- CONFIGURATION ---
# Path to the cwebp binary (Apple Silicon default)
# If using Intel mac, usually: /usr/local/bin/cwebp
WEBP="/opt/homebrew/bin/cwebp"

# --- 1. UI GENERATION (SWIFT) ---
read -r -d '' SWIFT_CODE <<'EOF'
import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let alert = NSAlert()
alert.messageText = "WebP Conversion"
alert.informativeText = "Select your compression settings:"
alert.addButton(withTitle: "Compress")
alert.addButton(withTitle: "Cancel")

let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 25))
popUp.addItems(withTitles: ["Low (60)", "Medium (80)", "High (98)"])
popUp.selectItem(at: 1) // Default to Medium

let checkbox = NSButton(checkboxWithTitle: "Delete source files after processing", target: nil, action: nil)
checkbox.frame = NSRect(x: 0, y: 0, width: 240, height: 25)

let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 250, height: 60))
stack.orientation = .vertical
stack.alignment = .leading
stack.spacing = 10
stack.addView(popUp, in: .top)
stack.addView(checkbox, in: .top)

alert.accessoryView = stack
app.activate(ignoringOtherApps: true)

let response = alert.runModal()

if response == .alertFirstButtonReturn {
    let quality = popUp.titleOfSelectedItem ?? "Medium (80)"
    let deleteState = (checkbox.state == .on) ? "YES" : "NO"
    print("\(quality)|\(deleteState)")
} else {
    print("CANCEL")
}
EOF

# Compile and run the Swift code
SWIFT_TMP=$(mktemp /tmp/webp_ui_XXXXXX.swift)
echo "$SWIFT_CODE" > "$SWIFT_TMP"
RESULT=$(swift "$SWIFT_TMP")
rm "$SWIFT_TMP"

# --- 2. PARSE RESULTS ---
if [ "$RESULT" = "CANCEL" ] || [ -z "$RESULT" ]; then exit 0; fi

CHOICE=$(echo "$RESULT" | cut -d "|" -f 1)
DELETE_FLAG=$(echo "$RESULT" | cut -d "|" -f 2)

case "$CHOICE" in
    "Low (60)") Q_VAL=60 ;;
    "Medium (80)") Q_VAL=80 ;;
    "High (98)") Q_VAL=98 ;;
    *) Q_VAL=80 ;;
esac

# --- 3. PROCESSING ---
count=0
for f in "$@"; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    filename="${base%.*}"
    output="$dir/$filename.webp"

    # Execute conversion
    "$WEBP" -q "$Q_VAL" -m 6 "$f" -o "$output"

    # Only delete if conversion succeeded AND user checked the box
    if [ $? -eq 0 ]; then
        ((count++))
        if [ "$DELETE_FLAG" = "YES" ]; then
            rm "$f"
        fi
    fi
done

osascript -e "display notification \"Processed $count images at $Q_VAL quality.\" with title \"WebP Conversion Complete\""
