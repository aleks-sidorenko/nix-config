# What `server` and the guest standing in for it share; each host's own module adds its disk.
{ lib, ... }:
{
  den.hosts.x86_64-linux = lib.genAttrs [ "server" "server-vm" ] (_: {
    users.alexander = { };
    stateVersion = "26.05";
    settings = {
      system.locale = {
        timeZone = "UTC";
        locales = [ "en_US.UTF-8" ];
        layouts = [ "us" ];
      };
      # The live world's players and rules.
      services.minecraft-server = {
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
        serverProperties.difficulty = "hard";
        gamerules = {
          keep_inventory = true;
          mob_griefing = true;
        };
      };
      services.tailscale.tags = [ "tag:server" ];
      storage.disko.encrypted = false;
    };
  });
}
