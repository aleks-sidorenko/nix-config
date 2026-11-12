{
  config,
  inputs,
  lib,
  ...
}:
let
  s = config.flake.nixosConfigurations.server.config;
  persisted = s.environment.persistence."/persist";
  owner = s.users.users.alexander;

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
  btrfsContent = s.disko.devices.disk.root.content.partitions.btrfs.content;
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
  flake = {
    modules.nixos.server = {
      imports = with config.flake.modules.nixos; [
        home-server
        alexander
        disko
        ./_hardware.nix
        ./_disks.nix
      ];

      sops.defaultSopsFile = ../../../secrets/server.yaml;

      # Do not change: tracks when NixOS was first installed on this machine.
      system.stateVersion = "26.05";
      home-manager.users.alexander.home.stateVersion = "26.05";
    };

    nixosConfigurations.server = inputs.self.lib.mkNixos "x86_64-linux" "server";

    deploy.nodes.server = {
      hostname = "server";
      profiles.system = {
        user = "root";
        # wheel is passwordless on system-server, so no interactiveSudo.
        sshUser = "alexander";
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.server;
      };
    };

  };

  evalTests = {
    # Everything but the blank-snapshot hook, which is now idempotent (only
    # formatting runs it; the deployed system never does).
    server-disko-matches-master = {
      expr = withoutHook (declarative s.disko.devices);
      expected = withoutHook disksOnMaster;
    };
    server-blank-snapshot-idempotent = {
      expr = lib.hasInfix ''[ -e "$MNTPOINT/@root-blank" ] ||'' btrfsContent.postCreateHook;
      expected = true;
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
    server-persisted-dirs = {
      expr = map (d: d.directory) persisted.directories;
      expected = [
        "/.cache/nix/"
        "/var/cache/"
        "/var/db/sudo/"
        "/var/lib/"
        "/etc/NetworkManager/system-connections"
      ];
    };
    server-persisted-files = {
      expr = map (f: f.file) persisted.files;
      expected = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
    server-alexander-groups = {
      expr = {
        inherit (owner) extraGroups group;
      };
      expected = {
        extraGroups = [
          "networkmanager"
          "input"
          "tty"
          "wheel"
        ];
        group = "users";
      };
    };
    server-alexander-password = {
      expr = owner.hashedPasswordFile;
      expected = "/run/secrets-for-users/user-alexander-password";
    };
    server-alexander-key = {
      expr = owner.openssh.authorizedKeys.keys;
      expected = [ (lib.trim (builtins.readFile ../../../identities/alexander/ssh.pub)) ];
    };
    server-root-no-keys = {
      expr = s.users.users.root.openssh.authorizedKeys.keys;
      expected = [ ];
    };
    server-mutable-users = {
      expr = s.users.mutableUsers;
      expected = false;
    };
    server-sudo-nopasswd = {
      expr = s.security.sudo.wheelNeedsPassword;
      expected = false;
    };
    server-firewall = {
      expr = s.networking.firewall.enable;
      expected = true;
    };
    server-locale = {
      expr = {
        inherit (s.i18n) supportedLocales defaultLocale;
        inherit (s.time) timeZone;
        layout = s.services.xserver.xkb.layout;
      };
      expected = {
        supportedLocales = [ "en_US.UTF-8/UTF-8" ];
        defaultLocale = "en_US.UTF-8";
        timeZone = "UTC";
        layout = "us";
      };
    };
    server-tailscale-tag = {
      expr = s.services.tailscale.extraUpFlags;
      expected = [ "--advertise-tags=tag:server" ];
    };
    server-host-key-persist = {
      expr = map (k: k.path) s.services.openssh.hostKeys;
      expected = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    };
    server-sops-file = {
      expr = lib.hasSuffix "/secrets/server.yaml" (toString s.sops.defaultSopsFile);
      expected = true;
    };
    # A path value copies just this file to the store; a string built from the
    # flake source would put the whole repo in the closure and change it on
    # every commit.
    server-sops-file-alone = {
      expr = builtins.isPath s.sops.defaultSopsFile;
      expected = true;
    };
    server-watchdog = {
      expr = {
        inherit (s.systemd.settings.Manager) RuntimeWatchdogSec RebootWatchdogSec;
      };
      expected = {
        RuntimeWatchdogSec = "20s";
        RebootWatchdogSec = "30s";
      };
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
    deploy-server-users = {
      expr = {
        inherit (config.flake.deploy.nodes.server.profiles.system) user sshUser;
      };
      expected = {
        user = "root";
        sshUser = "alexander";
      };
    };
  };
}
