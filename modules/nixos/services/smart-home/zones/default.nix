{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let

  # Define the zone submodule
  zoneType = types.submodule (
    { config, ... }:
    {
      options = {
        floor = mkOption {
          type = types.enum [
            "outdoors"
            "basement"
            "floor1"
            "floor2"
          ];
          description = "Floor level of the zone";
        };

        zone = mkOption {
          type = types.enum [
            "bath"
            "bedroom"
            "boiler"
            "garage"
            "guest"
            "hall"
            "kids"
            "kitchen"
            "laundry"
            "living"
            "main"
            "office"
            "shower"
            "terrace"
            "toilet"
            "wardrobe"
          ];
          description = "Zone type/room designation";
        };

        id = mkOption {
          type = types.str;
          default = mkId [
            config.floor
            config.zone
          ];
          readOnly = true;
          description = "Unique name/identifier for the zone (automatically derived as floor_zone)";
        };

        friendly_name = mkOption {
          type = types.str;
          readOnly = true;
          default = mkFriendlyName [
            config.floor
            config.zone
          ];
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

          floor1_hall = {
            floor = "floor1";
            zone = "hall";
          };

          floor1_kitchen = {
            floor = "floor1";
            zone = "kitchen";
          };

          floor1_living = {
            floor = "floor1";
            zone = "living";
          };


          floor2_bath = {
            floor = "floor2";
            zone = "bath";
          };

          floor2_bedroom = {
            floor = "floor2";
            zone = "bedroom";
          };

          floor2_office = {
            floor = "floor2";
            zone = "office";
          };

          floor2_shower = {
            floor = "floor2";
            zone = "shower";
          };

        }
      '';
    };
  };

  config = {
    ${namespace}.services.smart-home.zones.all = mkDefault {
      # Outdoor zones
      outdoors_terrace = {
        floor = "outdoors";
        zone = "terrace";
      };

      # Basement zones
      basement_boiler = {
        floor = "basement";
        zone = "boiler";
      };

      basement_main = {
        floor = "basement";
        zone = "main";
      };

      # First floor zones
      floor1_garage = {
        floor = "floor1";
        zone = "garage";
      };

      floor1_hall = {
        floor = "floor1";
        zone = "hall";
      };

      floor1_kitchen = {
        floor = "floor1";
        zone = "kitchen";
      };

      floor1_laundry = {
        floor = "floor1";
        zone = "laundry";
      };

      floor1_living = {
        floor = "floor1";
        zone = "living";
      };

      floor1_toilet = {
        floor = "floor1";
        zone = "toilet";
      };

      # Second floor zones
      floor2_bath = {
        floor = "floor2";
        zone = "bath";
      };

      floor2_kids = {
        floor = "floor2";
        zone = "kids";
      };

      floor2_office = {
        floor = "floor2";
        zone = "office";
      };

      floor2_shower = {
        floor = "floor2";
        zone = "shower";
      };

      floor2_hall = {
        floor = "floor2";
        zone = "hall";
      };
    };
  };
}
