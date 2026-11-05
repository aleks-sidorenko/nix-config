{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.disk-report;
in
{
  options.${namespace}.cli.tools.disk-report = with types; {
    enable = mkBoolOpt false "Whether or not to enable disk usage reporting tools";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.${namespace}.disk-report
      pkgs.nix-tree
    ];
  };
}
