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
  cfg = config.${namespace}.cli.terminals.foot;
in
{
  options.${namespace}.cli.terminals.foot = with types; {
    enable = mkBoolOpt false "Enable foot terminal emulator";
    default = mkBoolOpt false "Whether or not to use foot as the default terminal";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.terminals.default = mkIf cfg.default {
      enable = true;
      name = "foot";
      package = pkgs.foot;
    };

    programs.foot = {
      enable = true;

      settings = {
        main = {
          # term = "foot";
          shell = "fish";
          pad = "15x15";
          selection-target = "clipboard";
        };

        scrollback = {
          lines = 10000;
        };
      };
    };
  };
}
