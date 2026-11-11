{ config, ... }:
{
  flake.modules.nixos.prowlarr = {
    imports = [
      (config.factory.arr {
        name = "prowlarr";
        title = "Prowlarr";
        userDescription = "Prowlarr indexer manager user";
        dataDir = "/var/lib/private/prowlarr";
      })
    ];

    services.prowlarr = {
      settings.server.port = 9696;
      # TODO: enable once https://github.com/NixOS/nixpkgs/issues/445983 is fixed
      # dataDir = "/var/lib/private/prowlarr";
    };
  };
}
