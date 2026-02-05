{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.communication.viber;
in
{
  options.${namespace}.communication.viber = with types; {
    enable = mkBoolOpt false "Enable Viber via Homebrew";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew.casks = [
      "viber"
    ];
  };
}
