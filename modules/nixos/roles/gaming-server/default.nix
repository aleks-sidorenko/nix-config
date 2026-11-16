{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.gaming-server;
in
{
  options.${namespace}.roles.gaming-server = {
    enable = mkEnableOption "Enable gaming server role";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services = {
        gaming = {
          minecraft-server = {
            enable = true;
            ops = [
              {
                uuid = "036251c9-562e-48b6-af54-1ae7a154c01f"; # https://mcuuid.net/?q=s1dus
                name = "s1dus";
                level = 4;
                bypassesPlayerLimit = true;
              }
            ];
            whitelist = {
              d1mius = "80fd0535-faba-4838-ba48-38e61a51f38b";
              s1dus = "036251c9-562e-48b6-af54-1ae7a154c01f";
            };
            serverProperties = {
              difficulty = "hard";
            };
            # Gamerules applied via datapack on world load
            gamerules = {
              keep_inventory = true;
              mob_griefing = true;
            };
          };
        };
      };
    };
  };
}
