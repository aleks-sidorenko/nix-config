# TODO - move to nixos/disks/
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let

  cfg = config.${namespace}.system.boot;
in
{
  options.${namespace}.system.boot = with types; {
    enable = mkBoolOpt false "Whether or not to enable booting.";
    secureBoot = mkBoolOpt false "Whether or not to enable secure boot.";
    device = mkOpt str "root" "The boot device name";
    debug = mkBoolOpt false "Enable debug mode";
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        efibootmgr
        efitools
        efivar
        fwupd
      ]
      ++ lib.optionals cfg.secureBoot [ sbctl ];

    boot = {

      loader = {
        # systemd-boot fails https://github.com/NixOS/nixpkgs/issues/45032
        grub = {
          enable = true;
          devices = [ "nodev" ];
          efiSupport = true;
        };
        efi.canTouchEfiVariables = true;
      };

      initrd = {
        systemd.enable = true;
        # Verbose initrd output
        verbose = cfg.debug;
      };

      # Increase console log level (4 is default, 7 is maximum)
      consoleLogLevel = if cfg.debug then 7 else 4;

    };

    # services.fwupd.enable = true;
  };
}
