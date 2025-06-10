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
  cfg = config.${namespace}.cli.editors.default;

in
{
  options.${namespace}.cli.editors.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default editor configuration.";
    name = mkStringOpt' "The name of the default editor to use.";

  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "Please specify a editor name and package in ${namespace}.cli.editors.default.";
      }
    ];

    home.sessionVariables = {
      VISUAL = cfg.name;
      EDITOR = cfg;
    };
  };
}
