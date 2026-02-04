{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.shells.fish;
in
{
  options.${namespace}.cli.shells.fish = with types; {
    enable = mkEnableOption "Whether or not to enable fish shell on host level";
    default = mkBoolOpt false "Whether or not to use fish as the default shell";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.shells.default = mkIf cfg.default {
      enable = true;
      name = "fish";
      package = pkgs.fish;
    };

    programs.fish = {
      enable = true;
      vendor = {
        completions.enable = true;
        config.enable = true;
        functions.enable = true;
      };
    };
  };
}
