{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.roles.common;
in
{
  options.${namespace}.roles.common = {
    enable = mkEnableOption "Enable common configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {

      services = {
        openssh.enable = true;
      };

      security = {
        sops.enable = true;
        yubikey.enable = true;
      };

      system = {
        nix.enable = true;
        boot.enable = true;
        locale.enable = true;
        networking.enable = true;
      };

      styles.stylix.enable = true;

    };

  };
}
