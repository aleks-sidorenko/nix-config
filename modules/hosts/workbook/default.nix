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
    settings = {
      # Work VPN, specific to this host.
      services.openvpn.connections.kpi.profileSecret = "system-vpn-kpi-profile";
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
      den.aspects.services.openvpn
      den.aspects.dev.akeyless
      den.aspects.dev.stacks
    ];
    # darwin's own integer release, apart from the string `stateVersion` homes read.
    darwin.system.stateVersion = 5;
  };

  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == "aarch64-darwin") {
        # Sources the installed library, so the check runs what direnv will.
        stacks-script =
          pkgs.runCommand "stacks-script"
            {
              nativeBuildInputs = [ pkgs.bash ];
              script = hm.xdg.configFile."direnv/lib/stacks.sh".source;
            }
            ''
              set -eu
              PATH_add() { PATH="$1:$PATH"; }
              source "$script"

              fail() { echo "FAIL: $*" >&2; exit 1; }
              on_path() { [[ "$(command -v "$1")" == /nix/store/* ]] || fail "$1 not on PATH"; }

              (
                use_stack jvm
                for t in java sbt mvn gradle metals; do on_path "$t"; done
                [ -x "$JAVA_HOME/bin/java" ] || fail "JAVA_HOME=$JAVA_HOME"
              )
              (
                use_stack node
                for t in node npm; do on_path "$t"; done
                [ "$NPM_CONFIG_REGISTRY" = "https://npm.dev.wixpress.com/api/npm/npm-repos/" ] \
                  || fail "NPM_CONFIG_REGISTRY=$NPM_CONFIG_REGISTRY"
                [ -z "''${NPM_CONFIG_PREFIX:-}" ] || fail "npm prefix set"
              )
              for args in nope ""; do
                if err=$(use_stack $args 2>&1 >/dev/null); then fail "use_stack $args succeeded"; fi
                [[ "$err" == *jvm* && "$err" == *node* ]] || fail "message: $err"
              done
              touch $out
            '';
      };
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
    dev-git = {
      expr = {
        lfs = hm.programs.git.lfs.enable;
        ignoresClaude = lib.elem ".claude/" hm.programs.git.ignores;
      };
      expected = {
        lfs = true;
        ignoresClaude = true;
      };
    };
    dev-git-signing = {
      expr = {
        key = lib.hasPrefix "key::" hm.programs.git.signing.key;
        inherit (hm.programs.git.signing) signByDefault;
        signer =
          lib.hasPrefix (builtins.fromJSON (builtins.readFile ../../../identities/alexander/git.json)).email
            hm.home.file.".ssh/allowed_signers".text;
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
    gui-communication = {
      expr = lib.subtractLists (map (c: c.name or c) w.homebrew.casks) [
        "slack"
        "telegram"
        "zoom"
      ];
      expected = [ ];
    };
    gui-media = {
      expr = {
        cc = lib.elem "adobe-creative-cloud" (map (c: c.name or c) w.homebrew.casks);
        vlc = lib.any (lib.hasPrefix "vlc-bin") (map lib.getName hm.home.packages);
        tools = lib.elem "media-tools" (map lib.getName hm.home.packages);
        home = hm.home.sessionVariables.MEDIA_HOME;
      };
      expected = {
        cc = true;
        vlc = true;
        tools = true;
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
        keys = [ (lib.trim (builtins.readFile ../../../identities/alexander/gpg.key-id)) ];
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
        user = hm.programs.ssh.matchBlocks."*".data.user;
        agent = hm.programs.ssh.matchBlocks."*".data.addKeysToAgent;
        pub = hm.home.file.".ssh/id_ed25519.pub".source;
      };
      expected = {
        enable = true;
        user = "alexander";
        agent = "no";
        pub = ../../../identities/alexander/ssh.pub;
      };
    };
    workbook-secrets = {
      expr = lib.sort lib.lessThan (lib.attrNames w.sops.secrets);
      expected = [
        "system-github-token"
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
        "viber"
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
