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
  cfg = config.${namespace}.cli.tools.nix-ld;
in
{
  options.${namespace}.cli.tools.nix-ld = with types; {
    enable = mkBoolOpt false "Whether or not to enable nix-ld";
  };

  config = mkIf cfg.enable {
    programs.nix-ld.enable = true;
  };
}
