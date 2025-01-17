{
  config,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.cli.programs.bat;
in {
  options.cli.programs.bat = with types; {
    enable = mkBoolOpt false "Whether or not to enable bat";
  };

  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;
    };
  };
}
