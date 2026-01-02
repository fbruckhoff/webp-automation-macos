#!/bin/bash

# --- CONFIGURATION ---
# Path to the cwebp binary (Apple Silicon default)
# If using Intel mac, usually: /usr/local/bin/cwebp
WEBP="/opt/homebrew/bin/cwebp"

# --- 1. UI GENERATION (SWIFT) ---
# We use Swift to create a dialog with a Dropdown AND a Checkbox
# because standard AppleScript cannot do both in one window.

read -r -d '' SWIFT_CODE <<'EOF'
import Cocoa

// Setup the App context
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Create the Alert (Dialog)
let alert = NSAlert()
alert.messageText = "WebP Conversion"
alert.informativeText = "Select your compression settings:"
alert.addButton(withTitle: "Compress")
alert.addButton(withTitle: "Cancel")

// Create Dropdown (PopUpButton)
let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 25))
popUp.addItems(withTitles: ["Low (60)", "Medium (80)", "High (98)"])
popUp.selectItem(at: 1) // Default to Medium

// Create Checkbox
let checkbox = NSButton(checkboxWithTitle: "Delete source files after processing", target: nil, action: nil)
checkbox.frame = NSRect(x: 0, y: 0, width: 240, height: 25)

// Layout (StackView)
let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 250, height: 60))
stack.orientation = .vertical
stack.alignment = .leading
stack.spacing = 10
stack.addView(popUp, in: .top)
stack.addView(checkbox, in: .top)

alert.accessoryView = stack

// Bring dialog to front
app.activate(ignoringOtherApps: true)

// Run Modal
let response = alert.runModal()

if response == .alertFirstButtonReturn {
    // User clicked Compress
    let quality = popUp.titleOfSelectedItem ?? "Medium (80)"
    let deleteState = (checkbox.state == .on) ? "YES" : "NO"
    print("\(quality)|\(deleteState)")
} else {
    // User clicked Cancel
    print("CANCEL")
}
EOF

# Compile and run the Swift code on the fly
# We use a temporary file to avoid complex escaping issues
SWIFT_TMP=$(mktemp /tmp/webp_ui_XXXXXX.swift)
echo "$SWIFT_CODE" > "$SWIFT_TMP"
RESULT=$(swift "$SWIFT_TMP")
rm "$SWIFT_TMP"

# --- 2. PARSE RESULTS ---

# Check for cancellation
if [ "$RESULT" = "CANCEL" ] || [ -z "$RESULT" ]; then
    exit 0
fi

# Extract Quality Choice and Delete Flag using delimiter "|"
CHOICE=$(echo "$RESULT" | cut -d "|" -f 1)
DELETE_FLAG=$(echo "$RESULT" | cut -d "|" -f 2)

# Map choice to numeric quality value
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
    *)
        Q_VAL=80 # Fallback
        ;;
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

    # Check if conversion was successful (Exit code 0)
    if [ $? -eq 0 ]; then
        ((count++))

        # Only delete if checkbox was YES
        if [ "$DELETE_FLAG" = "YES" ]; then
            rm "$f"
        fi
    else
        # Optional: Log failure (osascript warning) if needed
        echo "Failed to convert $f"
    fi
done

# Final Notification
osascript -e "display notification \"Processed $count images at $Q_VAL quality.\" with title \"WebP Conversion Complete\""
