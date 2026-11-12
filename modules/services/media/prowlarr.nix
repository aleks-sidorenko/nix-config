{ config, ... }:
{
  flake.modules.nixos.prowlarr.imports = [
    (config.factory.arr {
      name = "prowlarr";
      title = "Prowlarr";
      userDescription = "Prowlarr indexer manager user";
      dataDir = "/var/lib/private/prowlarr";
      # TODO: pass the paths once https://github.com/NixOS/nixpkgs/issues/445983 is fixed
      upstreamPaths = false;
    })
  ];
}
