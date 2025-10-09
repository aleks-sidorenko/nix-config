{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.smart-home.devices;
  zones = config.${namespace}.services.smart-home.zones.all;

  # Define the device submodule
  deviceType = types.submodule (
    { config, ... }:
    {
      options = {
        zoneName = mkOption {
          type = types.enum (builtins.attrNames zones);
          description = "Zone where the device is located (reference to a zone name)";
          example = "floor1_living";
        };

        zone = mkOption {
          type = types.attrs;
          readOnly = true;
          default = zones.${config.zoneName};
          description = "Zone attribute set (derived from zoneName)";
        };

        name = mkOption {
          type = types.str;
          description = "Unique name/identifier for the device";
          example = "raam_zuid";
        };

        ieee = mkOption {
          type = types.str;
          description = "IEEE address of the device";
          example = "0x287681fffe7146ad";
        };

        type = mkOption {
          type = types.enum [
            "temperature"
            "button"
            "plug"
          ];
          description = "Type of the device";
          example = "temperature";
        };

        friendly_name = mkOption {
          type = types.str;
          default = "${config.zone.friendly_name}/${config.type}/${config.name}";
          description = "Human-readable name for the device";
        };

        # Home Assistant configuration
        homeassistant = mkOption {
          type = types.attrs;
          default = { };
          description = "Home Assistant specific configuration for this device";
        };
      };
    }
  );

in
{
  options.${namespace}.services.smart-home.devices = {

    all = mkOption {
      type = types.listOf deviceType;
      default = [ ];
      description = "Devices defined for the smart home system";
      example = literalExpression ''
        [
          {
            zoneName = "floor1_living";
            name = "meteostation";
            ieee = "0x287681fffe7146ad";
            type = "temperature";

          }

          {
            zoneName = "floor1_kitchen";
            name = "motion";
            ieee = "0x287681fffe123456";
            type = "button";

          }

          {
            zoneName = "floor2_bedroom";
            name = "light";
            ieee = "0x287681fffe789abc";
            type = "plug";

          }
        ];
      '';
    };
  };

  config = {
    ${namespace}.services.smart-home.devices.all = mkDefault [
      {
        zoneName = "floor1_garage";
        name = "sensor";
        type = "temperature";
        ieee = "0x00158d0007e48b59";
      }

      {
        zoneName = "floor2_office";
        name = "sensor";
        type = "temperature";
        ieee = "0x00158d0007e496fc";

      }
    ];

  };
}
