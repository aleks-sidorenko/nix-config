#!/usr/bin/env bash

set -euo pipefail

# Boot a VM guest from the installer ISO so it can be installed with
# nixos-anywhere, exactly as a physical host is.
# Usage: ./vm-install.sh <host>
# Example: ./vm-install.sh server-vm
#
# This is the VM equivalent of picking the USB stick from the boot menu: a
# deliberate, one-off act. The guest's steady-state launchd agent knows nothing
# about install media.

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

if [ $# -ne 1 ]; then
    log_error "Usage: $0 <host>"
    log_error "Example: $0 server-vm"
    exit 1
fi

host="$1"

# macOS only: the launcher is a launchd agent's program and the firmware comes
# from an aarch64-darwin package. A NixOS host runs guests under libvirt/KVM,
# which needs different plumbing entirely.
if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script must run on the macOS host that runs the guest."
    exit 1
fi

if [ "$(nix eval --raw .#nixosConfigurations --apply "f: if builtins.hasAttr \"$host\" f then \"yes\" else \"no\"")" != "yes" ]; then
    log_error "No such host in this flake: $host"
    exit 1
fi

# Reading the launcher off the agent rather than rebuilding the command line is
# what keeps install and steady-state boots identical.
launcher=$(nix eval --raw \
    ".#darwinConfigurations.workbook.config.launchd.user.agents.qemu-$host.serviceConfig.ProgramArguments" \
    --apply 'a: builtins.head a' 2>/dev/null || true)
if [ -z "$launcher" ]; then
    log_error "$host is not declared as a QEMU guest on the workbook"
    log_error "Only VM guests can be installed this way — a physical host boots its own media"
    exit 1
fi

# Asked of the flake rather than hardcoded: isoImage.isoName is a dead option
# in this nixpkgs, so the real filename comes from image.baseName and a
# hardcoded prefix can silently fail to match it.
iso_name=$(nix eval --raw '.#install-isoConfigurations.minimal-aarch64.name')
iso="result/iso/$iso_name"
if [ ! -e "$iso" ]; then
    log_error "No aarch64 installer ISO found — run 'just iso-build minimal-aarch64' first"
    exit 1
fi

# RunAtLoad=true/KeepAlive=false leaves the launchd job registered even after
# qemu fails to exec (e.g. no disk images yet), so "loaded" alone cannot mean
# "in use". A job in `not running` or `spawn scheduled` holds no open file
# handles — booting the guest directly is safe, so it's left alone entirely (a
# bootout here would only unregister it from the domain until next login,
# turning the documented `kickstart -k` below into a hard failure). Only
# `running` is a guest someone may be using, and a second QEMU contending for
# the same qcow2 files risks corrupting them, so it needs explicit consent; a
# state this doesn't recognize gets the same consent prompt, since it can't
# prove the job holds no handles either — fail safe, not open. A missing job
# (`launchctl print` exits non-zero) never enters this block at all.
agent="gui/$(id -u)/org.nixos.qemu-$host"
if agent_status=$(launchctl print "$agent" 2>/dev/null); then
    state=$(echo "$agent_status" | sed -n 's/^[[:space:]]*state = //p' | head -1)
    case "$state" in
    "not running" | "spawn scheduled")
        : # idle registration; nothing to clear, booting from the ISO starts it
        ;;
    *)
        if [ "$state" = "running" ]; then
            log_warning "The guest is running — installing now risks corrupting its disks"
        else
            log_warning "The guest's launchd job is in an unrecognized state ('$state') — treating it as potentially in use"
        fi
        if ! confirm bootout "Type 'bootout' to stop the guest and continue: "; then
            log_error "Aborted"
            exit 1
        fi
        launchctl bootout "$agent" 2>/dev/null || true
        ;;
    esac
fi

out="$HOME/.local/share/qemu/$host"
mkdir -p "$out"

# Resolved once and reused for both the firmware template and qemu-img, so the
# tooling matches the emulator the launcher will run.
qemu=$(nix build --no-link --print-out-paths \
    '.#darwinConfigurations.workbook.config.nix-config.services.virtualisation.qemu.package')

# Firmware varstore, seeded from that same qemu.
if [ ! -e "$out/vars.img" ]; then
    cp "$qemu/share/qemu/edk2-arm-vars.fd" "$out/.vars.img.tmp"
    chmod u+w "$out/.vars.img.tmp"
    mv -f "$out/.vars.img.tmp" "$out/vars.img"
    log_success "vars.img seeded"
fi

# Blank disks, sized from the guest's own disko layout so there is no second
# source of truth. Create-only: an existing disk is never silently replaced.
create_disk() {
    local file="$1" disk="$2" size
    if [ -e "$out/$file" ]; then
        log_info "Keeping the existing $out/$file — delete it by hand to start over"
        return
    fi
    size=$(nix eval --raw ".#nixosConfigurations.$host.config.disko.devices.disk.$disk.imageSize")
    "$qemu/bin/qemu-img" create -f qcow2 "$out/.$file.tmp" "$size" >/dev/null
    mv -f "$out/.$file.tmp" "$out/$file"
    log_success "$file created ($size)"
}

create_disk root.qcow2 root
create_disk data.qcow2 data

log_info "Booting $host from $iso"
log_info "The guest is headless: watch /tmp/qemu-$host.console.log for its console."
log_info "Once it has an address, install from another terminal with:"
log_info "    just bootstrap $host nixos --build-on-remote"
log_info "Quit this QEMU when the install finishes, then start the guest normally:"
log_info "    launchctl kickstart -k gui/\$(id -u)/org.nixos.qemu-$host"

exec "$launcher" --install "$iso"
