die() {
    echo "iso-write: $*" >&2
    exit 1
}

[ $# -eq 2 ] || die "Usage: iso-write <image> <device>"
image="$1"
device="$2"

# The raw node is what dd writes to below; the checks need the disk itself.
[ "$(uname -s)" = Darwin ] && device="${device/\/dev\/rdisk//dev/disk}"

[ -f "$image" ] || die "$image is not a file; build or fetch the image first"
[ -b "$device" ] || die "$device is not a whole disk (not a block device)"

# A partition would take the image but never boot; an internal disk is almost
# always the machine's own system disk.
if [ "$(uname -s)" = Darwin ]; then
    info=$(diskutil info "$device" 2>/dev/null) || die "$device is not a disk diskutil knows"
    grep -qE '^ *Whole: +Yes' <<<"$info" || die "$device is a partition, not a whole disk"
    if grep -qE '^ *(Device Location: +Internal|Internal: +Yes)' <<<"$info"; then
        die "$device is an internal disk; refusing"
    fi
    # APFS containers and disk images report as whole disks too, but live
    # inside another disk's partition.
    if grep -qE '^ *Virtual: +Yes' <<<"$info"; then
        die "$device is a virtual disk (APFS container or image); write to the physical disk"
    fi
else
    [ "$(lsblk -ndo TYPE "$device")" = disk ] || die "$device is a partition, not a whole disk"
    read -r removable transport < <(lsblk -ndo RM,TRAN "$device")
    if [ "$removable" != 1 ] && [ "${transport:-}" != usb ]; then
        die "$device is neither removable nor USB; refusing"
    fi
fi

# Typing the device back catches naming the wrong disk, which a timed window
# does not. A closed stdin would otherwise exit silently at `read`.
[ -t 0 ] || die "confirmation needs a terminal; run this interactively"
echo "About to write $image to $device; this destroys everything on it." >&2
read -rp "Type '$device' to confirm: " reply
[ "$reply" = "$device" ] || die "aborted"

# macOS refuses raw writes to a disk with mounted volumes, and its raw node is
# several times faster than the buffered one.
target="$device"
if [ "$(uname -s)" = Darwin ]; then
    diskutil unmountDisk "$device" >&2
    target="${device/\/dev\/disk//dev/rdisk}"
else
    while read -r part mountpoint; do
        [ -n "${mountpoint:-}" ] && sudo umount "$part"
    done < <(lsblk -lnpo NAME,MOUNTPOINT "$device")
fi

sudo dd if="$image" of="$target" bs=4194304 status=progress
sync
echo "Written; boot from $device." >&2
