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
  # nix-darwin lists every defaults key, null when unset.
  set = lib.filterAttrs (_: v: v != null);
in
{
  den.hosts.aarch64-darwin.workbook = {
    users.oleksandrsy.identity = "alexander";
    stateVersion = "25.05";
    # Work VPN, specific to this host.
    settings.services.openvpn.connections.kpi.profileSecret = "system-vpn-kpi-profile";
    settings.system.networking.knownNetworkServices = [
      "Wi-Fi"
      "USB 10/100/1000 LAN"
      "ThinkPad TBT 3 Dock"
      "Thunderbolt Bridge"
    ];
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
    cli-fish = {
      expr = {
        # The user-shell battery enables fish alone; these only cli.fish sets.
        abbr = hm.programs.fish.shellAbbrs ? nrs;
        plugins = map (p: p.name) hm.programs.fish.plugins;
      };
      expected = {
        abbr = true;
        plugins = [
          "bass"
          "fzf-fish"
          "fifc"
          "git-abbr"
        ];
      };
    };
    cli-fzf = {
      expr = {
        inherit (hm.programs.fzf) enable enableFishIntegration;
        bg = hm.programs.fzf.colors.bg;
      };
      expected = {
        enable = true;
        enableFishIntegration = false;
        bg = "#${hm.lib.stylix.colors.base00}";
      };
    };
    cli-htop = {
      expr = hm.programs.htop.settings.hide_userland_threads;
      expected = 1;
    };
    cli-bat = {
      expr = {
        inherit (hm.programs.bat) enable;
        pager = hm.home.sessionVariables.MANPAGER;
      };
      expected = {
        enable = true;
        pager = "batman";
      };
    };
    workbook-home-basics = {
      expr = {
        hmSelf = hm.programs.home-manager.enable;
        path = lib.elem "$HOME/.local/bin" hm.home.sessionPath;
      };
      expected = {
        hmSelf = true;
        path = true;
      };
    };
    cli-starship = {
      expr = hm.programs.starship.enable;
      expected = true;
    };
    cli-atuin = {
      expr = hm.programs.atuin.enable;
      expected = true;
    };
    cli-zellij = {
      expr = hm.programs.zellij.enable;
      expected = true;
    };
    cli-yazi = {
      expr = hm.programs.yazi.enable;
      expected = true;
    };
    cli-ghostty = {
      expr = lib.getName hm.programs.ghostty.package;
      expected = "ghostty-bin";
    };
    cli-ghostty-dock = {
      expr = lib.elem "${hm.home.homeDirectory}/Applications/Home Manager Apps/Ghostty.app" (
        map (a: a.tile-data.file-data._CFURLString) w.system.defaults.dock.persistent-apps
      );
      expected = true;
    };
    cli-nvim = {
      expr = {
        on = hm.programs.nix-nvim.enable;
        haskell = hm.programs.nix-nvim.development.haskell.enable;
        typescript = hm.programs.nix-nvim.development.typescript.enable;
      };
      expected = {
        on = true;
        haskell = false;
        typescript = true;
      };
    };
    cli-nix-index = {
      expr = {
        inherit (hm.programs.nix-index) enable;
        comma = hm.programs.nix-index-database.comma.enable;
      };
      expected = {
        enable = true;
        comma = true;
      };
    };
    cli-utils = {
      expr = lib.subtractLists (map lib.getName hm.home.packages) [
        "eza"
        "zoxide"
        "bottom"
        "moreutils"
        "coreutils"
        "nix-output-monitor"
        "nvd"
        "nix-tree"
        "disk-report"
        "zip"
        "unzip"
        "xz"
        "pdfcpu"
        "ghostscript"
        "wireshark-cli"
        "termshark"
        "kubeshark"
        "broot"
        "choose"
        "curlie"
        "chafa"
        "doggo"
        "duf"
        "delta"
        "du-dust"
        "dysk"
        "entr"
        "erdtree"
        "fd"
        "gdu"
        "gping"
        "grex"
        "hyperfine"
        "hexyl"
        "jq"
        "jqp"
        "jnv"
        "ouch"
        "silver-searcher"
        "procs"
        "tokei"
        "trash-cli"
        "tailspin"
        "gtrash"
        "ripgrep"
        "gnused"
        "sd"
        "xcp"
        "yq-go"
        "viddy"
        "kaf"
      ];
      expected = [ ];
    };
    system-stylix = {
      expr = {
        home = hm.stylix.enable;
        dark = w.system.defaults.NSGlobalDomain.AppleInterfaceStyle;
      };
      expected = {
        home = true;
        dark = "Dark";
      };
    };
    workbook-homebrew = {
      expr = {
        inherit (w.homebrew) enable;
        inherit (w.homebrew.onActivation) cleanup autoUpdate upgrade;
        path = lib.hasInfix "/opt/homebrew/bin" w.environment.systemPath;
      };
      expected = {
        enable = true;
        cleanup = "none";
        autoUpdate = false;
        upgrade = false;
        path = true;
      };
    };
    workbook-no-sleep = {
      expr = w.power.sleep.computer;
      expected = "never";
    };
    workbook-file-limits = {
      expr = map (d: w.launchd.daemons.${d}.serviceConfig.RunAtLoad) [
        "sysctl-fs-limits"
        "launchctl-maxfiles"
      ];
      expected = [
        true
        true
      ];
    };
    workbook-touch-id = {
      expr = {
        inherit (w.security.pam.services.sudo_local) touchIdAuth reattach;
      };
      expected = {
        touchIdAuth = true;
        reattach = true;
      };
    };
    workbook-dns = {
      expr = {
        inherit (w.networking) dns search knownNetworkServices;
      };
      expected = {
        dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        search = [
          "colobus-bramble.ts.net"
          "lan"
        ];
        knownNetworkServices = [
          "Wi-Fi"
          "USB 10/100/1000 LAN"
          "ThinkPad TBT 3 Dock"
          "Thunderbolt Bridge"
        ];
      };
    };
    workbook-dock-defaults = {
      expr = set (removeAttrs w.system.defaults.dock [ "persistent-apps" ]);
      expected = {
        autohide = true;
        mru-spaces = false;
        show-recents = false;
        tilesize = 48;
      };
    };
    workbook-finder-defaults = {
      expr = set w.system.defaults.finder;
      expected = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
      };
    };
    workbook-input-defaults = {
      expr = {
        trackpad = set w.system.defaults.trackpad;
        global = {
          inherit (w.system.defaults.NSGlobalDomain)
            InitialKeyRepeat
            KeyRepeat
            NSAutomaticCapitalizationEnabled
            NSAutomaticSpellingCorrectionEnabled
            ;
          fnState = w.system.defaults.NSGlobalDomain."com.apple.keyboard.fnState";
        };
        hotkeys = lib.mapAttrs (
          _: k: k.enabled
        ) w.system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys;
      };
      expected = {
        trackpad = {
          Clicking = true;
          TrackpadThreeFingerDrag = true;
        };
        global = {
          InitialKeyRepeat = 15;
          KeyRepeat = 2;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          fnState = true;
        };
        hotkeys = {
          "32" = false;
          "36" = false;
          "79" = false;
          "81" = false;
        };
      };
    };
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
