{
  pkgs,
  lib,
  config,
  host,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.shells.zsh;
in
{
  options.${namespace}.cli.shells.zsh = with types; {
    enable = mkEnableOption "Enable zsh shell";
    default = mkBoolOpt false "Whether or not to use zsh as the default shell";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.shells.default = mkIf cfg.default {
      enable = true;
      name = "zsh";
      package = pkgs.zsh;
    };

    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
    };
  };
}
