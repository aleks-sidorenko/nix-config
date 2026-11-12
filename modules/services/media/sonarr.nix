{ config, ... }:
{
  flake.modules.nixos.sonarr.imports = [
    (config.factory.arr {
      name = "sonarr";
      title = "Sonarr";
      userDescription = "Sonarr TV show management user";
      category = "series";
    })
  ];
}
