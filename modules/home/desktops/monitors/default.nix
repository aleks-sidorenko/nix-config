{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.monitors;
in
{
  options.${namespace}.desktops.monitors = with types; {
    enable = mkBoolOpt false "Enable monitors settings";
    devices = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              example = "HDMI-1";
            };
            model = mkOption {
              type = types.str;
              example = "Dell U2414H";
            };
            primary = mkOption {
              type = types.bool;
              default = false;
            };
            width = mkOption {
              type = types.int;
              example = 1920;
            };
            height = mkOption {
              type = types.int;
              example = 1080;
            };
            refreshRate = mkOption {
              type = types.int;
              default = 60;
            };
            position = mkOption {
              type = types.str;
              default = "auto";
            };
            scale = mkOption {
              type = types.str;
              default = "1";
            };
            enabled = mkOption {
              type = types.bool;
              default = true;
            };
            workspace = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          };
        }
      );
      default = [ ];
      description = "List of monitor devices to configure";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          ((lib.length cfg.devices) != 0) -> ((lib.length (lib.filter (m: m.primary) cfg.devices)) == 1);
        message = "Exactly one monitor must be set to primary.";
      }
    ];
  };
}
