{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.roles.minimal;
in
{
  options.${namespace}.roles.minimal = {
    enable = mkEnableOption "Enable the minimal base configuration (bare live/installer base)";
  };

  config = mkIf cfg.enable {
    ${namespace} = {

      security = {
        ssh.enable = true;
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

    };
  };
}
