{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.nh;
in
{
  options.${namespace}.cli.tools.nh = with types; {
    enable = mkBoolOpt false "Whether to enable nh (Nix helper)";
    clean = {
      enable = mkBoolOpt true "Whether to enable automatic GC via launchd";
      extraArgs = mkOpt str "--keep-since 7d --keep 5" "Extra arguments for nh clean";
    };
  };

  config = mkIf cfg.enable {
    # Install nh system-wide
    environment.systemPackages = [ pkgs.nh ];

    # Set flake directory for nh
    environment.variables.FLAKE = flakeDir config;

    # Configure nix GC via launchd (darwin equivalent of systemd timer)
    nix.gc = mkIf cfg.clean.enable {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      }; # Weekly on Sunday 3am
      options = "--delete-older-than 7d";
    };
  };
}
