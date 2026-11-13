{
  den.aspects.system.boot.nixos.boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        # Each generation's kernel and initrd take room on the ESP.
        configurationLimit = 3;
      };
    };
    initrd.systemd.enable = true;
  };
}
