{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.virtualbox;
in
{
  options.${namespace}.services.virtualisation.virtualbox = {
    enable = lib.mkEnableOption "enable VirtualBox virtualisation";

    enableExtensionPack = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable VirtualBox Extension Pack (requires accepting Oracle license).
        Provides USB 2.0/3.0, RDP, disk encryption, NVMe and PXE boot support.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    ${namespace}.user.extraGroups = [
      "vboxusers"
    ];

    virtualisation.virtualbox.host = {
      enable = true;
      enableExtensionPack = cfg.enableExtensionPack;
    };

  };
}
