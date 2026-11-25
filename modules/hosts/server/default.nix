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
  # "master" in these names is master before the rewrite merged: the snowfall tree.
  master = lib.importJSON ./_services-master.json;
  same = path: {
    expr = lib.getAttrFromPath path (parityOf s);
    expected = lib.getAttrFromPath path master;
  };
  persisted = map (d: d.dirPath) s.environment.persistence."/persist".directories;
  persistsAll = paths: {
    expr = lib.all (p: lib.elem p persisted) paths;
    expected = true;
  };
  inherit (config.flake.nixosConfigurations.server.pkgs) unstable;
  minecraft = config.den.hosts.x86_64-linux.server.settings.services.minecraft-server;
  inherit (import ./_parity.nix { inherit lib; }) declarative withoutHook mounts;

  # server-vm stands in for server in CI; these are its only intended differences.
  sv = config.flake.nixosConfigurations.server-vm.config;
  withoutDevice =
    devices:
    lib.recursiveUpdate devices {
      disk.root = {
        device = null;
        content = {
          device = null;
          partitions.btrfs.content.subvolumes."@swap".swap.swapfile.size = null;
        };
      };
    };
in
{
  # Shared with server-vm in ../home-servers.nix.
  den.hosts.x86_64-linux.server = {
    deploy = { };
    settings = {
      # Read from the wireless NIC; the wired one is 34:e3:da:d9:c1:f1, for when the box is cabled.
      system.networking.lan = {
        address = "10.0.0.10";
        mac = "80:30:49:13:75:41";
      };
      storage.disko.device = "/dev/disk/by-id/ata-SSD_2TB_004208";
    };
  };

  den.aspects.server = {
    includes = [
      den.aspects.roles.home-server
      den.aspects.system.networking.wifi
    ];
    nixos.imports = [ ./_hardware.nix ];
  };

  evalTests = {
    server-wifi = {
      expr =
        let
          inherit (s.networking.networkmanager.ensureProfiles) profiles environmentFiles;
        in
        {
          # The router's access point, so the two cannot drift.
          sameSsid =
            profiles.home-wifi.wifi.ssid
            == config.infraStacks.router.config.resource.routeros_wifi_configuration.home.ssid;
          readsSecret = environmentFiles == [ s.sops.templates."wifi.env".path ];
          secret = s.sops.secrets ? system-wifi-password;
        };
      expected = {
        sameSsid = true;
        readsSecret = true;
        secret = true;
      };
    };
    server-lan = {
      expr = config.den.hosts.x86_64-linux.server.settings.system.networking.lan;
      expected = {
        address = "10.0.0.10";
        mac = "80:30:49:13:75:41";
      };
    };

    server-nix-unchanged = {
      expr = {
        trusted-users = lib.unique s.nix.settings.trusted-users;
        inherit (s.nix.settings) use-xdg-base-directories;
      };
      expected = {
        trusted-users = [
          "root"
          "@wheel"
        ];
        use-xdg-base-directories = true;
      };
    };

    server-search-unchanged = {
      expr = s.networking.search;
      expected = [
        "colobus-bramble.ts.net"
        "lan"
      ];
    };

    server-timezone-unchanged = {
      expr = s.time.timeZone;
      expected = "UTC";
    };

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
    # The snowfall tree's daemon at c3bfac7, which the nixpkgs pin preserves.
    server-nix-as-master = {
      expr = s.nix.package.version;
      expected = "2.35.3";
    };
    server-tools-as-master = {
      expr = lib.subtractLists (map lib.getName s.environment.systemPackages) [
        "efibootmgr"
        "efitools"
        "efivar"
        "fwupd"
        "jellyfin"
      ];
      expected = [ ];
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
    server-parity-firewall = same [ "firewall" ];
    server-has-htpasswd = {
      expr = s.sops.secrets ? service-ingress-htpasswd;
      expected = true;
    };
    server-parity-primary-groups = same [ "primaryGroups" ];
    # Losing these wipes saved connections on reboot and the box drops off the LAN.
    server-persists-network = persistsAll [
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
    ];
    server-parity-qbittorrent-user = same [
      "users"
      "qbittorrent"
    ];
    server-parity-qbittorrent-vhost = same [
      "vhosts"
      "qbittorrent"
    ];
    server-persists-qbittorrent = persistsAll [ "/var/lib/qbittorrent" ];
    server-qbittorrent-secret = {
      expr = s.sops.secrets ? service-qbittorrent-alexander-password;
      expected = true;
    };
    server-qbittorrent-vhost-auth = {
      expr = s.services.nginx.virtualHosts.qbittorrent.basicAuthFile;
      expected = s.sops.secrets.service-ingress-htpasswd.path;
    };
    server-parity-jellyfin-user = same [
      "users"
      "jellyfin"
    ];
    server-parity-jellyfin-vhost = same [
      "vhosts"
      "jellyfin"
    ];
    server-parity-minidlna-user = same [
      "users"
      "minidlna"
    ];
    server-parity-minidlna-vhost = same [
      "vhosts"
      "minidlna"
    ];
    server-parity-calibre-web-user = same [
      "users"
      "calibre-web"
    ];
    server-parity-calibre-web-vhost = same [
      "vhosts"
      "calibre"
    ];
    server-parity-jellyfin-dirs = same [ "jellyfin" ];
    server-persists-jellyfin = persistsAll [ "/var/lib/jellyfin" ];
    server-persists-minidlna = persistsAll [ "/var/cache/minidlna" ];
    server-persists-calibre-web = persistsAll [ "/var/lib/calibre-web" ];
    server-parity-sonarr-user = same [
      "users"
      "sonarr"
    ];
    server-parity-sonarr-vhost = same [
      "vhosts"
      "sonarr"
    ];
    server-persists-sonarr = persistsAll [ "/var/lib/sonarr" ];
    server-sonarr-from-unstable = {
      expr = s.services.sonarr.package.outPath;
      expected = unstable.sonarr.outPath;
    };
    server-parity-radarr-user = same [
      "users"
      "radarr"
    ];
    server-parity-radarr-vhost = same [
      "vhosts"
      "radarr"
    ];
    server-persists-radarr = persistsAll [ "/var/lib/radarr" ];
    server-radarr-from-unstable = {
      expr = s.services.radarr.package.outPath;
      expected = unstable.radarr.outPath;
    };
    server-parity-prowlarr-user = same [
      "users"
      "prowlarr"
    ];
    server-parity-prowlarr-vhost = same [
      "vhosts"
      "prowlarr"
    ];
    server-persists-prowlarr = persistsAll [ "/var/lib/private/prowlarr" ];
    server-prowlarr-from-unstable = {
      expr = s.services.prowlarr.package.outPath;
      expected = unstable.prowlarr.outPath;
    };
    # Prowlarr's state lives under it, and systemd refuses a looser mode.
    server-private-state-mode = {
      expr = lib.elem "d /var/lib/private 0700 root root -" s.systemd.tmpfiles.rules;
      expected = true;
    };
    server-flaresolverr-from-unstable = {
      expr = s.services.flaresolverr.package.outPath;
      expected = unstable.flaresolverr.outPath;
    };
    server-parity-recyclarr-user = same [
      "users"
      "recyclarr"
    ];
    server-persists-recyclarr = persistsAll [ "/var/lib/recyclarr" ];
    server-recyclarr-targets-arr-ports = {
      expr =
        let
          content = s.sops.templates."recyclarr.yml".content;
        in
        map (url: lib.hasInfix "base_url: ${url}\n" content) [
          "http://localhost:8989"
          "http://localhost:7878"
        ];
      expected = [
        true
        true
      ];
    };
    server-recyclarr-from-unstable = {
      expr = lib.elem unstable.recyclarr.outPath (map (p: p.outPath) s.environment.systemPackages);
      expected = true;
    };
    server-parity-minecraft-user = same [
      "users"
      "minecraft"
    ];
    server-persists-minecraft = persistsAll [ "/var/lib/minecraft" ];
    server-minecraft-from-unstable = {
      expr = s.services.minecraft-server.package.outPath;
      expected = unstable.minecraft-server.outPath;
    };
    server-minecraft-settings = {
      expr = {
        ops = lib.importJSON (builtins.toFile "ops.json" s.environment.etc."minecraft/ops.json".text);
        difficulty = s.services.minecraft-server.serverProperties.difficulty;
        whitelist = s.services.minecraft-server.serverProperties.white-list;
        inherit (minecraft) gamerules;
        inherit (s.services.minecraft-server) jvmOpts;
        datapackInstalled = lib.hasInfix "datapacks/nix-gamerules" s.systemd.services.minecraft-server.preStart;
        firewall = {
          tcp = lib.elem 25565 s.networking.firewall.allowedTCPPorts;
          udp = lib.elem 25565 s.networking.firewall.allowedUDPPorts;
        };
      };
      expected = {
        ops = [
          {
            uuid = "036251c9-562e-48b6-af54-1ae7a154c01f";
            name = "s1dus";
            level = 4;
            bypassesPlayerLimit = true;
          }
        ];
        difficulty = "hard";
        whitelist = "true";
        gamerules = {
          keep_inventory = true;
          mob_griefing = true;
        };
        datapackInstalled = true;
        jvmOpts = "-Xms2G -Xmx2G";
        firewall = {
          tcp = true;
          udp = true;
        };
      };
    };
    server-parity-restic = same [ "restic" ];
    server-parity-restic-user = same [
      "users"
      "restic"
    ];
    # Each earlier test pins one section; this catches a section none of them name.
    server-matches-master = {
      expr = lib.mapAttrs (k: _: (parityOf s).${k}) (removeAttrs master [ "secrets" ]);
      expected = removeAttrs master [ "secrets" ];
    };
    server-secrets-match-master = {
      expr = lib.sort lib.lessThan (parityOf s).secrets;
      expected = master.secrets;
    };
    # The live box's state, exactly: a missing path comes up empty after the first
    # reboot, an extra one is state the live box never had.
    server-persists-live-state = {
      expr = lib.sort lib.lessThan persisted;
      expected = lib.sort lib.lessThan [
        "/var/lib/jellyfin"
        "/var/lib/minecraft"
        "/var/lib/sonarr"
        "/var/lib/radarr"
        "/var/lib/qbittorrent"
        "/var/lib/recyclarr"
        "/var/lib/calibre-web"
        "/var/lib/tailscale"
        "/var/lib/NetworkManager"
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/lib/private/prowlarr"
        "/var/cache/minidlna"
        "/etc/NetworkManager/system-connections"
      ];
    };
    # The join key is an OAuth client secret, which registers only a tagged node.
    server-tailscale-tags = {
      expr = s.services.tailscale.extraUpFlags;
      expected = [ "--advertise-tags=tag:server" ];
    };
    # server-vm mirrors server's services; only the deployed host is published.
    server-publishes-dns-names = {
      expr = lib.unique (map (r: r.hostname) config.infraStacks.dns.config.locals.service_records);
      expected = [ "server" ];
    };
    server-vm-disk-like-server = {
      expr = withoutDevice (declarative sv.disko.devices);
      expected = withoutDevice (declarative s.disko.devices);
    };
    # The guest stands in for server in CI, so it must run what server runs.
    server-vm-like-server =
      let
        sections = c: lib.getAttrs [ "units" "timers" "vhosts" "users" ] (parityOf c);
      in
      {
        expr = sections sv;
        expected = sections s;
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
