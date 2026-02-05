{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.multiplexers.default;

in
{
  options.${namespace}.cli.multiplexers.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default multiplexer configuration";
    name = mkStringOpt' "The name of the default multiplexer to use";

  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "Please specify a multiplexer name in ${namespace}.cli.multiplexers.default";
      }
    ];

  };
}
