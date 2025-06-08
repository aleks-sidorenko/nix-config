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
  cfg = config.${namespace}.browsers.default;
  name = pkgs.firefox.pname;

in
{
  options.${namespace}.browsers.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default web browser.";
    name = mkStringOpt' "The name of the default browser to use.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "Please specify a browser name in ${namespace}.browsers.default.";
      }
    ];
  };
}
