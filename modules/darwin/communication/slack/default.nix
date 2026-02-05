{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.communication.slack;
in
{
  options.${namespace}.communication.slack = with types; {
    enable = mkBoolOpt false "Enable Slack via Homebrew";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew.casks = [
      "slack"
    ];
  };
}
