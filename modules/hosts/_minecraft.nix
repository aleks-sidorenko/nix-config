# The live world's players and rules, shared by `server` and the guest standing in for it.
{
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
}
