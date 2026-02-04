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
  cfg = config.${namespace}.cli.shells.fish;
in
{
  options.${namespace}.cli.shells.fish = {
    enable = mkEnableOption "Enable fish shell";
    default = mkBoolOpt false "Whether to use fish as the default shell";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.shells.default = mkIf cfg.default {
      enable = true;
      name = "fish";
      package = pkgs.fish;
    };

    # Enable fish at system level and add to /etc/shells
    programs.fish.enable = true;
  };
}
