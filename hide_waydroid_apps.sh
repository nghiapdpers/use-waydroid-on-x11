#!/bin/bash

# Hide Waydroid apps from system launcher by adding NoDisplay=true to desktop files

set -e

echo "Hiding Waydroid apps from system launcher..."

apps_found=0
for app_file in ~/.local/share/applications/waydroid.*.desktop; do
    # Check if file exists and is a regular file
    if [ ! -f "$app_file" ]; then
        continue
    fi
    
    apps_found=$((apps_found + 1))
    
    # Properly quote the variable to handle spaces in filenames
    if ! grep -q "^NoDisplay=true" "$app_file"; then
        # Create backup
        cp "$app_file" "$app_file.bak"
        
        # Add NoDisplay=true after Icon= line
        if grep -q "^Icon=" "$app_file"; then
            sed '/^Icon=/a NoDisplay=true' -i "$app_file"
        else
            # If no Icon= line, append to end
            echo "NoDisplay=true" >> "$app_file"
        fi
        
        echo "✓ Hidden: $(basename "$app_file")"
    fi
done

if [ $apps_found -eq 0 ]; then
    echo "No Waydroid app files found in ~/.local/share/applications/"
else
    echo "Successfully hidden $apps_found Waydroid app(s)"
fi
