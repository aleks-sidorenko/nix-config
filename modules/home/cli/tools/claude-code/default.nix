{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.claude-code;
in
{
  options.${namespace}.cli.tools.claude-code = with types; {
    enable = mkBoolOpt false "Whether or not to enable claude-code CLI";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      claude-code
    ];
  };
}


