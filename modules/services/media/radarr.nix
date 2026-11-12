{ config, ... }:
{
  flake.modules.nixos.radarr.imports = [
    (config.factory.arr {
      name = "radarr";
      title = "Radarr";
      userDescription = "Radarr movie management user";
      category = "movies";
    })
  ];
}
