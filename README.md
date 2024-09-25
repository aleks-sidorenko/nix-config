# Introduction

# Partitioning
```
export DISK=/dev/nvme0n1

parted $DISK -- mklabel gpt

# ESP
parted $DISK -- mkpart ESP fat32 1MB 512MB
parted $DISK -- set 1 esp on

# root
parted $DISK -- mkpart root ext4 512MB 100%

```

# Formatting
```
mkfs.vfat -n ESP ${DISK}p1

# Create encrypted partition
cryptsetup --verify-passphrase -v luksFormat ${DISK}p2
cryptsetup open ${DISK}p2 enc

# Create the swap inside the encrypted partition
pvcreate /dev/mapper/enc
vgcreate lvm /dev/mapper/enc

lvcreate --size 32G --name swap lvm
lvcreate --extents 100%FREE --name root lvm

# swap
mkswap -L swap /dev/lvm/swap
swapon /dev/lvm/swap


# root filesystem
mkfs.btrfs -L root /dev/lvm/root

# subvolumes

mount -t btrfs /dev/lvm/root /mnt

# We first create the subvolumes outlined above:
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/persist
btrfs subvolume create /mnt/log

# We then take an empty *readonly* snapshot of the root subvolume,
# which we'll eventually rollback to on every boot.
btrfs subvolume snapshot -r /mnt/root /mnt/root-blank

umount /mnt

```



# Installation

```
# Mount the directories

mount -o subvol=root,compress=zstd,noatime /dev/lvm/root /mnt

mkdir /mnt/home
mount -o subvol=home,compress=zstd,noatime /dev/lvm/root /mnt/home

mkdir /mnt/nix
mount -o subvol=nix,compress=zstd,noatime /dev/lvm/root /mnt/nix

mkdir /mnt/persist
mount -o subvol=persist,compress=zstd,noatime /dev/lvm/root /mnt/persist

mkdir -p /mnt/var/log
mount -o subvol=log,compress=zstd,noatime /dev/lvm/root /mnt/var/log

# don't forget this!
mkdir /mnt/boot
mount ${DISK}p1 /mnt/boot

# generate configurations
nixos-generate-config --root /mnt
```


#