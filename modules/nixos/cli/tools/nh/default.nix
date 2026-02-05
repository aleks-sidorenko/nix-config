{
  config,
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
    enable = mkBoolOpt false "Whether or not to enable nh";
  };

  config = mkIf cfg.enable {
    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 7d --keep 5";
      };
      flake = flakeDir config;
    };

    # to avoid evaluation warning: programs.nh.clean.enable and nix.gc.automatic are both enabled. Please use one or the other to avoid conflict.
    nix.gc.automatic = mkForce false;
  };
}
