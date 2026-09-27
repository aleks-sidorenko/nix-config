_: {
  boot = {
    initrd = {
      availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_net"
      ];
    };

    # Headless: the serial port QEMU redirects to a log file is the only
    # console, so a failed boot is visible instead of silent.
    kernelParams = [ "console=ttyAMA0" ];
  };
}
