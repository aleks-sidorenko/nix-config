{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.shells.fish;
in
{
  options.${namespace}.cli.shells.fish = with types; {
    enable = mkBoolOpt false "Whether or not to enable fish shell on host level.";
  };

  config = mkIf cfg.enable {
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
