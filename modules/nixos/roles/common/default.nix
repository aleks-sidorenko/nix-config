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

      security = {
        ssh.enable = true;
        sops.enable = true;
      };

      system = {
        nix.enable = true;
        locale.enable = true;
        networking.enable = true;
      };

      cli = {
        shells.fish = {
          enable = true;
          default = true;
        };
      };

      disks = {
        boot.enable = true;
        impermanence.enable = true;
      };

      user = {
        enable = true;
      };

    };

  };
}
