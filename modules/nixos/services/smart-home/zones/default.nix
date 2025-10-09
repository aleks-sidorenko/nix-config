{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.smart-home.zones;

  # Define the zone submodule
  zoneType = types.submodule (
    { config, ... }:
    {
      options = {
        floor = mkOption {
          type = types.enum [
            "garden"
            "basement"
            "floor1"
            "floor2"
          ];
          description = "Floor level of the zone";
        };

        zone = mkOption {
          type = types.enum [
            "boiler"
            "kitchen"
            "living"
            "hall"
            "kids"
            "guest"
            "toilet"
            "shower"
            "bath"
            "office"
            "bedroom"
            "garage"
            "laundry"
            "wardrobe"
            "main"
          ];
          description = "Zone type/room designation";
        };

        name = mkOption {
          type = types.str;
          default = "${config.floor}_${config.zone}";
          readOnly = true;
          description = "Unique name/identifier for the zone (automatically derived as floor_zone)";
        };

        friendly_name = mkOption {
          type = types.str;
          readOnly = true;
          default = "${config.floor}/${config.zone}";
          description = "Human-readable name for the zone";
        };
      };
    }
  );

in
{
  options.${namespace}.services.smart-home.zones = {

    all = mkOption {
      type = types.attrsOf zoneType;
      default = { };
      description = "Zones defined for the smart home system";
      example = literalExpression ''
        {

          basement_main = {
            floor = "basement";
            zone = "main";
          };

          floor1_kitchen = {
            floor = "floor1";
            zone = "kitchen";
          };

          floor1_living = {
            floor = "floor1";
            zone = "living";
          };

          floor2_bedroom = {
            floor = "floor2";
            zone = "bedroom";
          };

          floor2_office = {
            floor = "floor2";
            zone = "office";
          };

        }
      '';
    };
  };

  config = {
    ${namespace}.services.smart-home.zones.all = mkDefault {
      # Basement zones
      basement_hall = {
        floor = "basement";
        zone = "hall";
      };

      # First floor zones
      floor1_kitchen = {
        floor = "floor1";
        zone = "kitchen";
      };

      floor1_living = {
        floor = "floor1";
        zone = "living";
      };

      floor1_toilet = {
        floor = "floor1";
        zone = "toilet";
      };

      floor1_garage = {
        floor = "floor1";
        zone = "garage";
      };

      floor2_office = {
        floor = "floor2";
        zone = "office";
      };
    };
  };
}
