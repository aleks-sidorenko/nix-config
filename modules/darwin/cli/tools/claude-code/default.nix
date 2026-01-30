{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools."claude-code";
in
{
  options.${namespace}.cli.tools."claude-code" = {
    enable = mkBoolOpt false "Whether to enable claude-code CLI via Homebrew";
  };

  config = mkIf cfg.enable {
    # On Darwin, install via Homebrew since npmjs may be blocked
    ${namespace}.system.homebrew.brews = [ "claude-code" ];
  };
}
