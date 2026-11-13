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
    deploy.sshUser = "alexander";
    settings.storage.disko = {
      device = "/dev/disk/by-id/ata-SSD_2TB_004208";
      encrypted = false;
    };
  };

  den.aspects.server = {
    includes = [ den.aspects.roles.server ];
    nixos.imports = [ ./_hardware.nix ];
  };

  evalTests = {
    # The live disk must not change shape when server deploys from this tree.
    server-disko-matches-master = {
      expr = withoutHook (declarative s.disko.devices);
      expected = withoutHook (lib.importJSON ./_disko-master.json);
    };
    # Hidden by `withoutHook`, yet the boot-time rollback restores this snapshot.
    disko-snapshots-blank-root = {
      expr = lib.hasInfix ''btrfs subvolume snapshot -r "$MNTPOINT/@root" "$MNTPOINT/@root-blank"'' s.disko.devices.disk.root.content.partitions.btrfs.content.postCreateHook;
      expected = true;
    };
    # disko's install test formats twice; the second run must not snapshot again.
    disko-blank-snapshot-idempotent = {
      expr = lib.hasInfix ''btrfs subvolume show "$MNTPOINT/@root-blank" >/dev/null 2>&1 || btrfs subvolume snapshot -r'' s.disko.devices.disk.root.content.partitions.btrfs.content.postCreateHook;
      expected = true;
    };
    server-filesystems-match-master = {
      expr = mounts s.fileSystems;
      expected = lib.importJSON ./_filesystems-master.json;
    };
    deploy-only-server = {
      expr = lib.attrNames config.flake.deploy.nodes;
      expected = [ "server" ];
    };
    deploy-server = {
      expr = {
        inherit (config.flake.deploy.nodes.server) hostname sshUser;
        inherit (config.flake.deploy.nodes.server.profiles.system) interactiveSudo;
      };
      expected = {
        interactiveSudo = true;
        hostname = "server";
        sshUser = "alexander";
      };
    };
  };
}
