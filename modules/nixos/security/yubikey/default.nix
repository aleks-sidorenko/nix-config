{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.security.yubikey;
in {
  options.${namespace}.security.yubikey = with types; {
    enable = mkBoolOpt false "Whether to enable yubikey for auth.";
  };

  config = mkIf cfg.enable {
    services = {
      pcscd.enable = true;
      udev.packages = with pkgs; [yubikey-personalization];
      dbus.packages = [pkgs.gcr];
    };

    security.pam.services = {
      swaylock = {
        u2fAuth = true;
      };

      hyprlock = {
        u2fAuth = true;
      };

      login = {
        u2fAuth = true;
      };

      sudo = {
        u2fAuth = true;
      };
    };
  };
}
