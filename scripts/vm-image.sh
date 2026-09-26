#!/usr/bin/env bash

set -euo pipefail

# Build a VM guest's disk images and install them where its hypervisor expects.
# Usage: ./vm-image.sh <host>
# Example: ./vm-image.sh server-vm
#
# This targets QEMU guests running on macOS under launchd: it writes to
# ~/.local/share/qemu/<host>/, seeds a UEFI variable store from the qemu
# package's EDK2 firmware, and coordinates with the org.nixos.qemu-<host>
# agent. None of that is meaningful for a physical host, hence the guard below.

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

# macOS only, and it fails confusingly without this: launchctl does not exist
# elsewhere (the agent block would silently skip), and seeding the UEFI vars
# store realises an aarch64-darwin derivation, which no Linux machine can build.
# A NixOS host runs its guests under libvirt/KVM, which needs different plumbing
# entirely — not a variation of this script.
if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script must run on the macOS host that runs the guest."
    log_error "NixOS hosts run guests under libvirt/KVM, which this does not drive."
    exit 1
fi

# Fail before creating directories or inspecting launchd, so a typo does not
# leave debris behind. hasAttr is cheap; evaluating toplevel would also report a
# real assertion failure inside an existing host as "no such host".
if [ "$(nix eval --raw .#nixosConfigurations --apply "f: if builtins.hasAttr \"$host\" f then \"yes\" else \"no\"")" != "yes" ]; then
    log_error "No such host in this flake: $host"
    exit 1
fi

# The generic name is narrowed here rather than in the caller: imaging only
# means anything for a host this Mac actually runs as a guest.
if ! nix eval --raw .#darwinConfigurations --apply \
    "f: if builtins.any (n: builtins.hasAttr \"$host\" f.\${n}.config.nix-config.services.virtualisation.qemu.guests) (builtins.attrNames f) then \"yes\" else \"no\"" 2>/dev/null |
    grep -q yes; then
    log_error "$host is not declared as a QEMU guest on any darwin host in this flake"
    log_error "Only VM guests can be imaged — a physical host is installed, not imaged"
    exit 1
fi

out="$HOME/.local/share/qemu/$host"
mkdir -p "$out"

# RunAtLoad=true/KeepAlive=false leaves the launchd job registered even after
# qemu fails to exec (e.g. no disk images yet), so "loaded" alone cannot mean
# "in use". A job in `not running` or `spawn scheduled` holds no open file
# handles — `launchctl kickstart -k` starts it directly, so it's left alone
# entirely (a bootout here would only unregister it from the domain until next
# login, turning the documented `kickstart -k` that follows into a hard
# failure). Only `running` is a guest someone may be using, and killing that
# costs unsaved guest state, so it needs explicit consent; a state this doesn't
# recognize gets the same consent prompt, since it can't prove the job holds no
# handles either — fail safe, not open. A missing job (`launchctl print` exits
# 113) never enters this block at all.
agent="gui/$(id -u)/org.nixos.qemu-$host"
if agent_status=$(launchctl print "$agent" 2>/dev/null); then
    state=$(echo "$agent_status" | sed -n 's/^[[:space:]]*state = //p' | head -1)
    case "$state" in
    "not running" | "spawn scheduled")
        : # idle registration; nothing to clear, kickstart -k will start it
        ;;
    *)
        if [ "$state" = "running" ]; then
            log_warning "The guest is running — imaging now risks corrupting its disks"
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

install_image() {
    rm -f "$out/.$1.tmp"
    cp "result-vm/$2" "$out/.$1.tmp"
    chmod u+w "$out/.$1.tmp"
    mv -f "$out/.$1.tmp" "$out/$1"
}

# Firmware state is independent of the root-image decision below: seed it up
# front so a decline there still leaves the guest with a consistent varstore
# instead of none at all. The qemu package is read from the guest's own
# hypervisor host, so the firmware always matches the emulator that will load it.
if [ ! -e "$out/vars.img" ]; then
    qemu=$(nix build --no-link --print-out-paths '.#darwinConfigurations.workbook.config.nix-config.services.virtualisation.qemu.package')
    rm -f "$out/.vars.img.tmp"
    cp "$qemu/share/qemu/edk2-arm-vars.fd" "$out/.vars.img.tmp"
    chmod u+w "$out/.vars.img.tmp"
    mv -f "$out/.vars.img.tmp" "$out/vars.img"
    log_success "vars.img seeded"
fi

# Anything in the root image that is not on the data disk is lost — /persist
# included — so replacing it is never implicit.
if [ -e "$out/root.qcow2" ]; then
    log_warning "About to REPLACE $out/root.qcow2 — the guest's host key and all service state go with it"
    if ! confirm replace "Type 'replace' to continue: "; then
        log_error "Aborted"
        exit 1
    fi
fi

log_info "Building $host disk images (requires an aarch64-linux builder)..."
log_info "This runs under emulation and takes hours — -L streams the builder's"
log_info "output so you can see partitioning and installation progress."
# Without -L nix buffers a remote builder's log and flushes it only on
# completion, so a multi-hour build shows one static progress line and no way
# to tell work from a wedge.
nix build ".#nixosConfigurations.$host.config.system.build.diskoImages" --out-link result-vm -L

install_image root.qcow2 root.qcow2
log_success "root.qcow2 written"

# The data disk is the one thing that survives re-imaging: create-only.
if [ -e "$out/data.qcow2" ]; then
    log_info "Keeping the existing $out/data.qcow2 — delete it by hand to start over"
else
    install_image data.qcow2 data.qcow2
    log_success "data.qcow2 created"
fi

log_success "Images ready in $out"
