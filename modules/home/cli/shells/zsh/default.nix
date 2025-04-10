{
  pkgs,
  lib,
  config,
  host,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.shells.zsh;
in {
  options.${namespace}.cli.shells.zsh = with types; {
    enable = mkBoolOpt false "enable zsh shell";
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
    };
  };
}
