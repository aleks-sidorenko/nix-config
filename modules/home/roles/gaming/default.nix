{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.gaming;
in
{
  options.${namespace}.roles.gaming = with types; {
    enable = mkBoolOpt false "Whether or not to manage gaming configuration";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      games = {
        minecraft = enabled;
      };
    };
  };
}
