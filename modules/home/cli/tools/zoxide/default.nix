{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.tools.zoxide;
in {
  options.${namespace}.cli.tools.zoxide = with types; {
    enable = mkBoolOpt false "Whether or not to enable zoxide";
  };

  config = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
