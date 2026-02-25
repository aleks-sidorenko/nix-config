#!/bin/bash

# Usage: firmware.sh <target_dir> [version]
# Example: firmware.sh /mnt/boot v1.42

if [ $# -lt 1 ]; then
    echo "Usage: $0 <target_dir> [version]"
    echo "  target_dir: Directory where firmware files will be downloaded"
    echo "  version:    Firmware version (default: v1.42)"
    echo "Example: $0 /mnt/boot v1.42"
    exit 1
fi

target_dir="$1"
version="${2:-v1.42}"

# Check if target directory exists
if [ ! -d "$target_dir" ]; then
    echo "Error: Target directory '$target_dir' does not exist"
    exit 1
fi

echo "Downloading RPi4 UEFI Firmware $version to $target_dir"

cd "$target_dir"
wget https://github.com/pftf/RPi4/releases/download/$version/RPi4_UEFI_Firmware_$version.zip
unzip RPi4_UEFI_Firmware_$version.zip
rm RPi4_UEFI_Firmware_$version.zip

echo "Firmware installation completed successfully"