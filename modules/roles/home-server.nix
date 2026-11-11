{ config, ... }:
{
  flake.modules.nixos.home-server.imports = with config.flake.modules.nixos; [
    system-server
    media-server
  ];
}
