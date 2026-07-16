#!/bin/bash

# Usage: firmware.sh <target_dir> [version]
# Example: firmware.sh /mnt/boot v1.42
#
# Logging (log_info/log_success/log_error) is reused from scripts/common.sh,
# which the `just bootstrap-rpi-firmware` recipe prepends to this script before
# piping it over ssh. The fallback below keeps the script working if it is ever
# run standalone without common.sh prepended.
if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

if [ $# -lt 1 ]; then
    log_error "Usage: $0 <target_dir> [version]"
    log_error "  target_dir: Directory where firmware files will be downloaded"
    log_error "  version:    Firmware version (default: v1.42)"
    log_error "Example: $0 /mnt/boot v1.42"
    exit 1
fi

target_dir="$1"
version="${2:-v1.42}"

# Check if target directory exists
if [ ! -d "$target_dir" ]; then
    log_error "Target directory '$target_dir' does not exist"
    exit 1
fi

log_info "Downloading RPi4 UEFI Firmware $version to $target_dir"

cd "$target_dir"
wget "https://github.com/pftf/RPi4/releases/download/$version/RPi4_UEFI_Firmware_$version.zip"
unzip "RPi4_UEFI_Firmware_$version.zip"
rm "RPi4_UEFI_Firmware_$version.zip"

log_success "Firmware installation completed successfully"
