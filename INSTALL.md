# Hardware
I will have quite old PC with EUFI BIOS which doesn't support booting from NVME disks, so I decided to assign 2 disks to NixOS: 
* SSD for `/boot` & `/` (label: `root`)
* NVME for `/persist` (label: `persist`)


# Partitioning
```
# lsblk -l
export ROOT_DISK=/dev/sdc
export PERSIST_DISK=/dev/nvme0n1

parted $ROOT_DISK -- mklabel gpt
parted $PERSIST_DISK -- mklabel gpt

# ESP
parted $ROOT_DISK -- mkpart ESP fat32 1MB 512MB
parted $ROOT_DISK -- set 1 esp on

# root
parted $ROOT_DISK -- mkpart root ext4 512MB 100%

# persist
parted $PERSIST_DISK -- mkpart persist ext4 0% 100%


```

# Formatting
```
mkfs.vfat -n ESP ${ROOT_DISK}1

# Create encrypted partition
cryptsetup --verify-passphrase -v luksFormat ${ROOT_DISK}2
ryptsetup --verify-passphrase -v luksFormat ${PERSIST_DISK}
cryptsetup config ${ROOT_DISK}2 --label root_crypt
cryptsetup config ${PERSIST_DISK} --label persist_crypt

# Open the crypted partitions
cryptsetup open ${ROOT_DISK}2 root
cryptsetup open ${PERSIST_DISK} persist

export ROOT_FS=/dev/mapper/root
export PERSIST_FS=/dev/mapper/persist

# Create filesystems
mkfs.btrfs -L root ${ROOT_FS}
mkfs.btrfs -L persist ${PERSIST_FS}

# subvolumes

mount -t btrfs ${ROOT_FS} /mnt
mount -t btrfs ${PERSIST_FS} /mnt/persist

# We first create the subvolumes outlined above:
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/swap
btrfs subvolume create /mnt/nix

btrfs subvolume create /mnt/persist/persist


# We then take an empty *readonly* snapshot of the root subvolume,
# which we'll eventually rollback to on every boot.
btrfs subvolume snapshot -r /mnt/root /mnt/root-blank

umount /mnt

```



# Installation

## Mounting
```
# Mount the directories

mount -o subvol=root,compress=zstd,noatime ${ROOT_FS} /mnt

mkdir /mnt/swap
mount -o subvol=swap,noatime ${ROOT_FS} /mnt/swap
btrfs filesystem mkswapfile --size 33G /mnt/swap/swapfile
mkswap -L swap /mnt/swap/swapfile
swapon /mnt/swap/swapfile


mkdir /mnt/nix
mount -o subvol=nix,compress=zstd,noatime ${ROOT_FS} /mnt/nix

mkdir /mnt/persist
mount -o subvol=persist,compress=zstd ${PERSIST_FS} /mnt/persist


# boot
mkdir /mnt/boot
mount ${ROOT_DISK}1 /mnt/boot
```
## Configuring
### Generate
```
# generate configurations
nixos-generate-config --root /mnt

```

### Edit
* `/mnt/etc/nixos/configuration.nix`
* `/mnt/etc/nixos/hardware-configuration.nix`


## Install

```
nixos-install
reboot
```

#