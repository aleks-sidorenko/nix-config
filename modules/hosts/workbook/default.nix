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
  me = den.hosts.aarch64-darwin.workbook.users.alexander.identity;
  # nix-darwin lists every defaults key, null when unset.
  set = lib.filterAttrs (_: v: v != null);
in
{
  den.hosts.aarch64-darwin.workbook = {
    # The org names the account; the person is the same.
    users.alexander.userName = "oleksandrsy";
    stateVersion = "25.05";
    settings = {
      # Work VPN, specific to this host.
      services.openvpn.connections.kpi.profileSecret = "system-vpn-kpi-profile";
      services.tailscale.tags = [ "tag:workstation" ];
      system.networking.knownNetworkServices = [
        "Wi-Fi"
        "USB 10/100/1000 LAN"
        "ThinkPad TBT 3 Dock"
        "Thunderbolt Bridge"
      ];
      dev.stacks.npmRegistry = "https://npm.dev.wixpress.com/api/npm/npm-repos/";
    };
  };

  den.aspects.workbook = {
    includes = [
      den.aspects.roles.workstation
      # The employer's: its VPN and secrets CLI, not every workstation's.
      den.aspects.services.openvpn
      den.aspects.dev.akeyless
    ];
    # darwin's own integer release, apart from the string `stateVersion` homes read.
    darwin.system.stateVersion = 5;
  };

  evalTests = {
    cli-fish = {
      expr = {
        # The user-shell battery enables fish alone; these only cli.fish sets.
        abbr = hm.programs.fish.shellAbbrs ? nrs;
        # No NH_FLAKE on this host, so nh needs the flake and host spelled out.
        nho = hm.programs.fish.shellAbbrs.nho;
        plugins = map (p: p.name) hm.programs.fish.plugins;
      };
      expected = {
        abbr = true;
        nho = "nh darwin switch ~/.nix-config -H workbook";
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
        cat = hm.programs.fish.shellAbbrs.cat;
      };
      expected = {
        enable = true;
        pager = "batman";
        cat = "bat";
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
        "zellij"
        "broot"
        "choose"
        "curlie"
        "chafa"
        "doggo"
        "duf"
        "du-dust"
        "dysk"
        "fclones"
        "erdtree"
        "fd"
        "gdu"
        "gping"
        "grex"
        "hexyl"
        "jq"
        "jqp"
        "jnv"
        "ouch"
        "silver-searcher"
        "procs"
        "trash-cli"
        "tailspin"
        "gtrash"
        "ripgrep"
        "gnused"
        "sd"
        "xcp"
        "yq-go"
        "viddy"
      ];
      expected = [ ];
    };
    cli-utils-abbrs = {
      expr = {
        inherit (hm.programs.fish.shellAbbrs)
          cd
          df
          dig
          du
          ls
          ;
      };
      expected = {
        cd = "z";
        df = "duf";
        dig = "doggo";
        du = "dust";
        ls = "eza";
      };
    };
    dev-git = {
      expr = {
        lfs = hm.programs.git.lfs.enable;
        ignoresClaude = lib.elem ".claude/" hm.programs.git.ignores;
        gdub = lib.hasInfix "awk '{print $1}'" hm.programs.fish.shellAbbrs.gdub;
        gcrb = hm.programs.fish.functions ? gcrb;
      };
      expected = {
        lfs = true;
        ignoresClaude = true;
        gdub = true;
        gcrb = true;
      };
    };
    dev-k8s = {
      expr = {
        inherit (hm.programs.k9s) enable;
        k = hm.programs.fish.shellAbbrs.k;
        kubeshark = lib.elem "kubeshark" (map lib.getName hm.home.packages);
      };
      expected = {
        enable = true;
        k = "kubectl";
        kubeshark = true;
      };
    };
    dev-git-signing = {
      expr = {
        key = lib.hasPrefix "key::" hm.programs.git.signing.key;
        inherit (hm.programs.git.signing) signByDefault;
        signer = lib.hasPrefix me.git.email hm.home.file.".ssh/allowed_signers".text;
      };
      expected = {
        key = true;
        signByDefault = true;
        signer = true;
      };
    };
    dev-gh-keyring = {
      expr = hm.home.sessionVariables ? GITHUB_TOKEN;
      expected = false;
    };
    dev-direnv = {
      expr = {
        inherit (hm.programs.direnv) enable;
        nix = hm.programs.direnv.nix-direnv.enable;
      };
      expected = {
        enable = true;
        nix = true;
      };
    };
    stacks-installed = {
      expr = hm.xdg.configFile ? "direnv/lib/stacks.sh";
      expected = true;
    };
    stacks-envrc-ignored = {
      expr = lib.elem ".envrc" hm.programs.git.ignores;
      expected = true;
    };
    dev-projects = {
      expr = hm.home.sessionVariables ? PROJECTS_HOME;
      expected = true;
    };
    dev-containers = {
      expr = {
        casks = lib.elem "rancher" (map (c: c.name or c) w.homebrew.casks);
        brews = lib.subtractLists (map (b: b.name or b) w.homebrew.brews) [
          "lima"
          "docker"
          "docker-compose"
          "docker-credential-helper"
        ];
      };
      expected = {
        casks = true;
        brews = [ ];
      };
    };
    dev-containers-abbrs = {
      expr = hm.programs.fish.shellAbbrs.docker-compose;
      expected = "podman-compose";
    };
    dev-bazel = {
      expr = lib.subtractLists (map lib.getName hm.home.packages) [
        "bazel"
        "bazelisk"
        "bazel-buildtools"
      ];
      expected = [ ];
    };
    dev-xcode = {
      expr = w.homebrew.masApps.Xcode;
      expected = 497799835;
    };
    dev-akeyless = {
      expr = lib.elem "akeyless" (map (b: b.name or b) w.homebrew.brews);
      expected = true;
    };
    system-stylix = {
      expr = {
        home = hm.stylix.enable;
        dark = w.system.defaults.NSGlobalDomain.AppleInterfaceStyle;
        inherit (hm.catppuccin) flavor;
        scheme = baseNameOf hm.stylix.base16Scheme;
        wallpaper = toString hm.stylix.image;
      };
      expected = {
        home = true;
        dark = "Dark";
        flavor = "mocha";
        scheme = "catppuccin-mocha.yaml";
        wallpaper = toString inputs.nix-wallpapers.packages.aarch64-darwin.default.earth;
      };
    };
    workbook-homebrew = {
      expr = {
        inherit (w.homebrew) enable;
        inherit (w.homebrew.onActivation) cleanup autoUpdate upgrade;
      };
      expected = {
        enable = true;
        cleanup = "none";
        autoUpdate = false;
        upgrade = false;
      };
    };
    workbook-homebrew-after-nix = {
      expr =
        let
          dirs = lib.splitString ":" w.environment.systemPath;
          at = d: lib.lists.findFirstIndex (x: x == d) null dirs;
        in
        {
          afterNix = at "/opt/homebrew/bin" > at "/run/current-system/sw/bin";
          beforeSystem = at "/opt/homebrew/bin" < at "/usr/bin";
        };
      expected = {
        afterNix = true;
        beforeSystem = true;
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
      # `expose-group-by-app` is a renamed alias; reading it traces a warning.
      expr = set (
        removeAttrs w.system.defaults.dock [
          "persistent-apps"
          "expose-group-by-app"
        ]
      );
      expected = {
        autohide = true;
        mru-spaces = false;
        show-recents = false;
        tilesize = 48;
      };
    };
    workbook-finder-defaults = {
      expr = {
        finder = set w.system.defaults.finder;
        global = w.system.defaults.NSGlobalDomain.AppleShowAllExtensions;
      };
      expected = {
        finder = {
          AppleShowAllExtensions = true;
          ShowPathbar = true;
          ShowStatusBar = true;
          FXEnableExtensionChangeWarning = false;
          _FXShowPosixPathInTitle = true;
        };
        global = true;
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
        inherit (w.users.users.oleksandrsy) uid home isHidden;
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
        isHidden = false;
        shell = "fish";
        homeState = "25.05";
        key = [ me.sshKey ];
      };
    };
    workbook-hostname = {
      # The org manages ComputerName; only the network names are set.
      expr = { inherit (w.networking) hostName localHostName computerName; };
      expected = {
        hostName = "workbook";
        localHostName = "workbook";
        computerName = null;
      };
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
      expr =
        let
          c = w.launchd.daemons.nh-clean.serviceConfig;
          args = lib.concatStringsSep " " c.ProgramArguments;
        in
        {
          retention = lib.hasInfix "--keep-since 7d --keep 5" args;
          waitsForStore = lib.hasInfix "/bin/wait4path /nix/store" args;
          nixOnPath =
            c.EnvironmentVariables != null
            && lib.elem "${w.nix.package}/bin" (lib.splitString ":" c.EnvironmentVariables.PATH);
        };
      expected = {
        retention = true;
        waitsForStore = true;
        nixOnPath = true;
      };
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
      expr = {
        included = lib.hasInfix "!include" w.nix.extraOptions;
        inherit (w.sops.secrets.system-github-token) mode owner group;
      };
      expected = {
        included = true;
        mode = "0440";
        owner = "root";
        group = "staff";
      };
    };
    workbook-remote-login = {
      expr = w.services.openssh.enable;
      expected = true;
    };
    workbook-tailscale = {
      expr =
        let
          inherit (w.launchd.daemons.tailscale-autoconnect) script serviceConfig;
        in
        {
          on = w.services.tailscale.enable;
          secret = w.sops.secrets ? system-tailscale-auth-key;
          inherit (serviceConfig) RunAtLoad;
          retries = serviceConfig.KeepAlive.SuccessfulExit;
          readsKey = lib.hasInfix w.sops.secrets.system-tailscale-auth-key.path script;
          preauthorized = lib.hasInfix "preauthorized=true" script;
          tags = lib.hasInfix "--advertise-tags=tag:workstation" script;
        };
      expected = {
        on = true;
        secret = true;
        RunAtLoad = true;
        retries = false;
        readsKey = true;
        preauthorized = true;
        tags = true;
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
    gui-communication = {
      expr = lib.subtractLists (map (c: c.name or c) w.homebrew.casks) [
        "slack"
        "telegram"
        "viber"
        "zoom"
      ];
      expected = [ ];
    };
    gui-minecraft = {
      expr = lib.elem "prismlauncher" (map lib.getName hm.home.packages);
      expected = true;
    };
    gui-media = {
      expr = {
        cc = lib.elem "adobe-creative-cloud" (map (c: c.name or c) w.homebrew.casks);
        vlc = lib.any (lib.hasPrefix "vlc-bin") (map lib.getName hm.home.packages);
      };
      expected = {
        cc = true;
        vlc = true;
      };
    };
    cli-media = {
      expr = {
        tools = lib.subtractLists (map lib.getName hm.home.packages) [
          "ffmpeg"
          "media-tools"
        ];
        home = hm.home.sessionVariables.MEDIA_HOME;
      };
      expected = {
        tools = [ ];
        home = "/Users/oleksandrsy/Media";
      };
    };
    gui-raycast = {
      expr = lib.elem "raycast" (map (c: c.name or c) w.homebrew.casks);
      expected = true;
    };
    gui-chrome = {
      expr = {
        inherit (hm.programs.google-chrome) enable;
        bp = hm.programs.browserpass.enable;
      };
      expected = {
        enable = true;
        bp = true;
      };
    };
    workbook-dock = {
      expr = map (a: a.tile-data.file-data._CFURLString) w.system.defaults.dock.persistent-apps;
      expected = [
        "/Users/oleksandrsy/Applications/Home Manager Apps/Ghostty.app"
        "/Users/oleksandrsy/Applications/Home Manager Apps/Google Chrome.app"
        "/Applications/Slack.app"
      ];
    };
    security-gpg = {
      expr = {
        inherit (hm.programs.gpg) enable;
        ssh = hm.services.gpg-agent.enableSshSupport;
        keys = hm.services.gpg-agent.sshKeys;
        sock = hm.home.sessionVariables.SSH_AUTH_SOCK;
      };
      expected = {
        enable = true;
        ssh = true;
        keys = [ me.gpgKeyId ];
        sock = "$(gpgconf --list-dirs agent-ssh-socket)";
      };
    };
    security-pass = {
      expr = hm.programs.password-store.enable;
      expected = true;
    };
    security-ssh-client = {
      expr = {
        inherit (hm.programs.ssh) enable;
        user = hm.programs.ssh.settings."*".data.User;
        agent = hm.programs.ssh.settings."*".data.AddKeysToAgent;
        pub = hm.home.file.".ssh/id_ed25519.pub".source;
      };
      expected = {
        enable = true;
        user = "alexander";
        agent = "no";
        pub = me.sshKeyFile;
      };
    };
    workbook-secrets = {
      expr = lib.sort lib.lessThan (lib.attrNames w.sops.secrets);
      expected = [
        "system-github-token"
        "system-tailscale-auth-key"
        "system-vpn-kpi-profile"
      ];
    };
    workbook-no-global-toolchains = {
      expr = lib.filter (
        n:
        lib.any (p: lib.hasPrefix p n) [
          "zulu"
          "openjdk"
          "jdk"
          "temurin"
          "graalvm"
          "nodejs"
          "scala"
          "sbt"
          "maven"
          "gradle"
          "metals"
          "coursier"
        ]
      ) (map lib.getName (w.environment.systemPackages ++ hm.home.packages));
      expected = [ ];
    };
    workbook-no-global-toolchain-vars = {
      expr = lib.filter (n: n == "JAVA_HOME" || lib.hasPrefix "NPM_CONFIG_" n) (
        lib.attrNames hm.home.sessionVariables ++ lib.attrNames w.environment.variables
      );
      expected = [ ];
    };
    workbook-dropped = {
      expr = lib.intersectLists (map (c: lib.last (lib.splitString "/" (c.name or c))) w.homebrew.casks) [
        "teamviewer"
        "aerospace"
      ];
      expected = [ ];
    };
    workbook-nix-latest = {
      expr = lib.versionAtLeast w.nix.package.version "2.35";
      expected = true;
    };
  };
}
