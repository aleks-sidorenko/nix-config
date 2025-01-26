{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.services.nix-config.printing;
in {
  options.services.nix-config.printing = with types; {
    enable = mkBoolOpt false "Whether or not to configure printing support.";
  };

  config = mkIf cfg.enable {services.printing.enable = true;};
}
