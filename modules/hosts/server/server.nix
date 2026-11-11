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

  # Only the declarative fields: disko adds functions and `_`-prefixed internals.
  declarative =
    v:
    if builtins.isFunction v then
      null
    else if builtins.isAttrs v then
      if v ? outPath then
        "<path>"
      else
        lib.filterAttrs (_: x: x != null) (
          lib.mapAttrs (_: declarative) (lib.filterAttrs (n: _: !lib.hasPrefix "_" n) v)
        )
    else if builtins.isList v then
      map declarative v
    else
      v;

  # master's rendered layout and mounts: the live disk must not change shape.
  disksOnMaster = lib.importJSON ./_disko-master.json;
  btrfsContent = s.disko.devices.disk.root.content.partitions.btrfs.content;
  withoutHook =
    devices:
    lib.recursiveUpdate devices {
      disk.root.content.partitions.btrfs.content.postCreateHook = null;
    };
  mountsOnMaster = lib.importJSON ./_filesystems-master.json;
in
{
  flake = {
    modules.nixos.server = {
      imports = with config.flake.modules.nixos; [
        system-server
        alexander
        inputs.disko.nixosModules.disko
        ./_hardware.nix
        ./_disks.nix
      ];

      sops.defaultSopsFile = inputs.self + "/secrets/server.yaml";

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
    server-watchdog = {
      expr = {
        inherit (s.systemd.settings.Manager) RuntimeWatchdogSec RebootWatchdogSec;
      };
      expected = {
        RuntimeWatchdogSec = "20s";
        RebootWatchdogSec = "30s";
      };
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
