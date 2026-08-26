{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.zellij;
in
{
  options.${namespace}.cli.tools.zellij = {
    enable = mkEnableOption "the zellij terminal multiplexer";
  };

  config = mkIf cfg.enable {
    programs.zellij.enable = true;
  };
}
