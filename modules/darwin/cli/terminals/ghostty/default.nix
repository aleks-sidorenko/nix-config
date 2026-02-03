{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.terminals.ghostty;
in
{
  options.${namespace}.cli.terminals.ghostty = {
    enable = mkEnableOption "Install Ghostty terminal via Homebrew";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew.casks = [ "ghostty" ];
  };
}
