# Proof that the port renders what master does, for the first deploy onto the
# live box. Delete this file and the _*-master.json fixtures after that deploy.
{ config, lib, ... }:
let
  s = config.flake.nixosConfigurations.server.config;

  parity = import ./_parity.nix { inherit lib; };
  inherit (parity) declarative;
  media = parity.project s;
  # master's media stack as rendered; see _parity.nix for what is compared.
  mediaOnMaster = lib.importJSON ./_media-master.json;
  # 3c: minecraft is ported with the gaming-server role.
  minecraft = {
    port = 25565;
    name = "minecraft.home.sidorenko.me";
  };

  # master's rendered layout and mounts: the live disk must not change shape.
  disksOnMaster = lib.importJSON ./_disko-master.json;
  withoutHook =
    devices:
    lib.recursiveUpdate devices {
      disk.root.content.partitions.btrfs.content.postCreateHook = null;
    };
  mountsOnMaster = lib.importJSON ./_filesystems-master.json;

  # On master radarr and sonarr both declared the library root, and whichever
  # rule came first owned it; media-library now declares it once.
  mediaRoot = {
    onMaster = [
      "d /data/media 0775 sonarr media -"
      "d /data/media 0775 radarr media -"
    ];
    here = "d /data/media 0775 root media -";
  };

  # master redeclared the dirs upstream jellyfin already declares (as 700),
  # so tmpfiles warned of duplicates and master's 0755 won.
  jellyfinDirsOnMaster = map (d: "d /var/lib/jellyfin/${d} 0755 jellyfin media -") [
    "config"
    "cache"
    "log"
  ];

  # master forced minidlna's primary group to media, which the unit's pinned
  # Group= ignores; it now joins media as a supplementary group instead.
  minidlna = {
    user = {
      group = "minidlna";
      extraGroups = [ ];
    };
    serviceConfig.SupplementaryGroups = [ "media" ];
  };
in
{
  evalTests = {
    # Everything but the blank-snapshot hook, which is now idempotent (only
    # formatting runs it; the deployed system never does).
    server-disko-matches-master = {
      expr = withoutHook (declarative s.disko.devices);
      expected = withoutHook disksOnMaster;
    };
    server-filesystems-match-master = {
      expr = lib.mapAttrs (_: v: {
        inherit (v)
          neededForBoot
          device
          fsType
          options
          ;
      }) s.fileSystems;
      expected = mountsOnMaster;
    };
    server-media-templates = {
      expr = media.templates;
      expected = mediaOnMaster.templates;
    };
    server-media-secrets = {
      expr = media.secrets;
      expected = mediaOnMaster.secrets;
    };
    server-media-users = {
      expr = media.users;
      expected = lib.recursiveUpdate mediaOnMaster.users { minidlna = minidlna.user; };
    };
    server-media-tmpfiles = {
      expr = lib.sort lib.lessThan media.tmpfiles;
      expected = lib.sort lib.lessThan (
        lib.subtractLists (mediaRoot.onMaster ++ jellyfinDirsOnMaster) mediaOnMaster.tmpfiles
        ++ [ mediaRoot.here ]
      );
    };
    server-media-firewall = {
      expr = media.firewall;
      expected = lib.mapAttrs (_: lib.remove minecraft.port) mediaOnMaster.firewall;
    };
    server-media-vhosts = {
      expr = media.vhosts;
      expected = mediaOnMaster.vhosts;
    };
    server-media-units = {
      expr = media.units;
      expected = lib.recursiveUpdate mediaOnMaster.units {
        minidlna = { inherit (minidlna) serviceConfig; };
      };
    };
    server-media-jellyfin = {
      expr = media.jellyfin;
      expected = mediaOnMaster.jellyfin;
    };
    server-media-settings = {
      expr = media.settings;
      expected = mediaOnMaster.settings;
    };
    server-media-names = {
      expr = lib.sort lib.lessThan media.names;
      expected = lib.sort lib.lessThan (lib.remove minecraft.name mediaOnMaster.names);
    };
  };
}
