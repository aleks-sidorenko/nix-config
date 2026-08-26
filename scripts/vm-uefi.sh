#!/usr/bin/env bash
#
# Switch the Vagrant test VM to UEFI firmware.
#
# The generic/ubuntu2204 box boots legacy BIOS for the install phase, but the
# installed NixOS only has a UEFI bootloader (systemd-boot + ESP). Run this once
# after `just bootstrap vm ...` to power-cycle the VM into EFI so systemd-boot
# (via the removable fallback \EFI\BOOT\BOOTX64.EFI) loads the installed system.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ID_FILE="$SCRIPT_DIR/../systems/x86_64-linux/vm/.vagrant/machines/vm/virtualbox/id"

if ! command -v VBoxManage >/dev/null 2>&1; then
    log_error "VBoxManage not found — run this on the VirtualBox host (the desktop)."
    exit 1
fi

if [[ ! -f "$ID_FILE" ]]; then
    log_error "VM not provisioned ($ID_FILE missing)."
    log_error "Run 'vagrant up' in systems/x86_64-linux/vm first."
    exit 1
fi

id="$(cat "$ID_FILE")"

log_info "Powering off VM (if running)..."
VBoxManage controlvm "$id" poweroff >/dev/null 2>&1 || true

# VBoxManage refuses to modify a locked (running) VM, so wait for poweroff.
for _ in $(seq 1 30); do
    state="$(VBoxManage showvminfo "$id" --machinereadable | grep '^VMState=' | cut -d'"' -f2)"
    [[ "$state" == "poweroff" ]] && break
    sleep 1
done

log_info "Setting firmware to EFI..."
VBoxManage modifyvm "$id" --firmware efi

log_info "Starting VM (headless)..."
VBoxManage startvm "$id" --type headless

log_success "VM restarted under UEFI — systemd-boot should now load NixOS."
