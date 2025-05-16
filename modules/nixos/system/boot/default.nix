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
      kernelParams = [

      ];

      initrd = {
        systemd.enable = true;
        # Verbose initrd output
        verbose = true;
      };

      # Increase console log level (7 is maximum)
      consoleLogLevel = 7;

      lanzaboote = mkIf cfg.secureBoot {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };

      loader = {
        efi = {
          canTouchEfiVariables = true;
        };

        systemd-boot = {
          enable = !cfg.secureBoot;
          configurationLimit = 20;
          editor = false;
          consoleMode = "max";
        };
      };
    };

    # services.fwupd.enable = true;
  };
}
