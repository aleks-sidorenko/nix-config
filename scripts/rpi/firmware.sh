cd /mnt/boot
version=v1.42
wget https://github.com/pftf/RPi4/releases/download/$version/RPi4_UEFI_Firmware_$version.zip
unzip RPi4_UEFI_Firmware_$version.zip
rm README.md
rm RPi4_UEFI_Firmware_$version.zip