{
  config,
  den,
  inputs,
  lib,
  ...
}:
let
  w = config.flake.darwinConfigurations.workbook.config;
  hm = w.home-manager.users.oleksandrsy;
in
{
  den.hosts.aarch64-darwin.workbook = {
    users.oleksandrsy.identity = "alexander";
    stateVersion = "25.05";
    # Work VPN, specific to this host.
    settings.services.openvpn.connections.kpi.profileSecret = "system-vpn-kpi-profile";
  };

  den.aspects.workbook = {
    includes = [
      den.aspects.roles.workstation
      den.aspects.services.openvpn
    ];
    # darwin's own integer release, apart from the string `stateVersion` homes read.
    darwin.system.stateVersion = 5;
  };

  evalTests = {
    workbook-user = {
      expr = {
        inherit (w.system) primaryUser stateVersion;
        # nix-darwin adds its build users.
        known = lib.filter (u: !lib.hasInfix "nixbld" u) w.users.knownUsers;
        inherit (w.users.users.oleksandrsy) uid home;
        shell = lib.getName w.users.users.oleksandrsy.shell;
        homeState = hm.home.stateVersion;
        key = w.users.users.oleksandrsy.openssh.authorizedKeys.keys;
      };
      expected = {
        primaryUser = "oleksandrsy";
        stateVersion = 5;
        known = [ "oleksandrsy" ];
        uid = 501;
        home = "/Users/oleksandrsy";
        shell = "fish";
        homeState = "25.05";
        key = [ (lib.trim (builtins.readFile ../../../identities/alexander/ssh.pub)) ];
      };
    };
    workbook-hostname = {
      expr = w.networking.hostName;
      expected = "workbook";
    };
    workbook-nix = {
      expr = {
        trusted-users = lib.unique w.nix.settings.trusted-users;
        xdg = w.nix.settings.use-xdg-base-directories or false;
        hmGlobalPkgs = w.home-manager.useGlobalPkgs;
        hmBackup = w.home-manager.backupFileExtension;
      };
      expected = {
        trusted-users = [
          "root"
          "@admin"
        ];
        xdg = false;
        hmGlobalPkgs = true;
        hmBackup = "backup";
      };
    };
    workbook-no-timezone = {
      expr = w.time.timeZone;
      expected = null;
    };
    workbook-registry = {
      expr = { inherit (w.nix.registry.nixpkgs.to) type path; };
      expected = {
        type = "path";
        path = inputs.nixpkgs.outPath;
      };
    };
    workbook-nh-clean = {
      expr = lib.hasInfix "--keep-since 7d --keep 5" (
        lib.concatStringsSep " " w.launchd.daemons.nh-clean.serviceConfig.ProgramArguments
      );
      expected = true;
    };
    workbook-sops = {
      expr = {
        file = w.sops.defaultSopsFile;
        keys = w.sops.age.sshKeyPaths;
      };
      expected = {
        file = ../../../secrets/darwin.yaml;
        keys = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
    };
    workbook-access-token = {
      expr = lib.hasInfix "!include" w.nix.extraOptions;
      expected = true;
    };
    workbook-remote-login = {
      expr = w.services.openssh.enable;
      expected = true;
    };
    workbook-tailscale = {
      expr = {
        on = w.services.tailscale.enable;
        secrets = w.sops.secrets ? system-tailscale-auth-key;
      };
      expected = {
        on = true;
        secrets = false;
      };
    };
    openvpn-kpi-daemon = {
      expr =
        let
          c = w.launchd.daemons.openvpn-kpi.serviceConfig;
        in
        {
          reads = lib.elem w.sops.secrets.system-vpn-kpi-profile.path c.ProgramArguments;
          ignoresDns = lib.hasInfix "--pull-filter ignore dhcp-option DNS" (
            lib.concatStringsSep " " c.ProgramArguments
          );
          inherit (c) KeepAlive RunAtLoad;
        };
      expected = {
        reads = true;
        ignoresDns = true;
        KeepAlive = false;
        RunAtLoad = false;
      };
    };
    workbook-secrets = {
      expr = lib.sort lib.lessThan (lib.attrNames w.sops.secrets);
      expected = [
        "system-github-token"
        "system-vpn-kpi-profile"
      ];
    };
  };
}
