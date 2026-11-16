{
  config,
  den,
  inputs,
  lib,
  ...
}:
let
  s = config.flake.nixosConfigurations.server.config;
  parityOf = import ./_parity-services.nix;
  master = lib.importJSON ./_services-master.json;
  same = path: {
    expr = lib.getAttrFromPath path (parityOf s);
    expected = lib.getAttrFromPath path master;
  };
  inherit (import ./_parity.nix { inherit lib; }) declarative withoutHook mounts;
in
{
  den.hosts.x86_64-linux.server = {
    users.alexander = { };
    stateVersion = "26.05";
    timeZone = "UTC";
    locales = [ "en_US.UTF-8" ];
    layouts = [ "us" ];
    deploy.sshUser = "alexander";
    settings.storage.disko = {
      device = "/dev/disk/by-id/ata-SSD_2TB_004208";
      encrypted = false;
    };
  };

  den.aspects.server = {
    includes = [ den.aspects.roles.home-server ];
    nixos.imports = [ ./_hardware.nix ];
  };

  evalTests = {
    nixpkgs-pinned-to-master = {
      expr = {
        stable = inputs.nixpkgs.rev;
        unstable = inputs.nixpkgs-unstable.rev;
      };
      expected = {
        stable = "7dcdd87373d72e7a2173e4db02e20d3d7f495cfd";
        unstable = "1d060086d60cb76a40cf37109f979d88a5bd6396";
      };
    };
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
    server-parity-boot-limit = same [
      "misc"
      "bootLimit"
    ];
    server-parity-networking = same [ "networking" ];
    server-parity-locale = same [ "locale" ];
    server-parity-sudo = same [ "sudo" ];
    server-parity-manager = same [ "manager" ];
    server-parity-misc = same [ "misc" ];
    server-parity-default-vhost = same [
      "vhosts"
      "_"
    ];
    server-parity-tailnet-ingress = same [
      "firewall"
      "interfaces"
    ];
    server-has-htpasswd = {
      expr = s.sops.secrets ? service-ingress-htpasswd;
      expected = true;
    };
    server-parity-primary-groups = same [ "primaryGroups" ];
    # Losing these wipes saved connections on reboot and the box drops off the LAN.
    server-persists-network = {
      expr =
        let
          dirs = map (d: d.dirPath) s.environment.persistence."/persist".directories;
        in
        lib.all (p: lib.elem p dirs) [
          "/etc/NetworkManager/system-connections"
          "/var/lib/NetworkManager"
        ];
      expected = true;
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
        interactiveSudo = false;
        hostname = "server";
        sshUser = "alexander";
      };
    };
  };
}
