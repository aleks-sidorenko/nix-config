_: {
  boot = {
    initrd = {
      availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_net"
        "virtio_gpu"
        "usbhid"
      ];
    };

    # The guest renders on virtio-gpu; there is no vendor GPU to mask off.
    kernelModules = [ "virtio_gpu" ];
  };
}
