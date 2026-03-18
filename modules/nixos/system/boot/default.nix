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
    enable = mkBoolOpt false "Whether or not to enable booting";
    debug = mkBoolOpt false "Enable debug mode";
    configurationLimit = mkOpt int 3 "Maximum number of configurations in boot menu";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      efibootmgr
      efitools
      efivar
      fwupd
    ];

    boot = {

      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          inherit (cfg) configurationLimit;
        };
        grub.enable = mkForce false;
      };

      initrd = {
        systemd.enable = true;
        # Verbose initrd output
        verbose = cfg.debug;
      };

      # Increase console log level (4 is default, 7 is maximum)
      consoleLogLevel = if cfg.debug then 7 else 4;

    };

  };
}
