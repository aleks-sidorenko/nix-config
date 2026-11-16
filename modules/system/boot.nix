{
  den.aspects.system.boot.nixos =
    { pkgs, ... }:
    {
      boot = {
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

      # Fixing boot entries or firmware from a shell needs these on the box.
      environment.systemPackages = [
        pkgs.efibootmgr
        pkgs.efitools
        pkgs.efivar
        pkgs.fwupd
      ];
    };
}
