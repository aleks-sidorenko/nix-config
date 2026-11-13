{
  config,
  den,
  lib,
  ...
}:
let
  s = config.flake.nixosConfigurations.server.config;
  inherit (import ./_parity.nix { inherit lib; }) declarative withoutHook mounts;
in
{
  den.hosts.x86_64-linux.server = {
    users.alexander = { };
    stateVersion = "26.05";
    settings.storage.disko = {
      device = "/dev/disk/by-id/ata-SSD_2TB_004208";
      encrypted = false;
    };
  };

  den.aspects.server = {
    includes = [ den.aspects.storage.disko ];

    nixos = {
      imports = [ ./_hardware.nix ];
      # Stand-in until system.boot provides a boot loader.
      boot.loader.grub.enable = false;
    };
  };

  # The live disk must not change shape when server deploys from this tree.
  evalTests = {
    server-disko-matches-master = {
      expr = withoutHook (declarative s.disko.devices);
      expected = withoutHook (lib.importJSON ./_disko-master.json);
    };
    server-filesystems-match-master = {
      expr = mounts s.fileSystems;
      expected = lib.importJSON ./_filesystems-master.json;
    };
  };
}
