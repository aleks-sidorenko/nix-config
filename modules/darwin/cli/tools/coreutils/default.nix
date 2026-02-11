{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.coreutils;
in
{
  options.${namespace}.cli.tools.coreutils = with types; {
    enable = mkBoolOpt false "Enable coreutils via Homebrew";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      system.homebrew.brews = [
        "coreutils"
      ];
    };

  };
}
