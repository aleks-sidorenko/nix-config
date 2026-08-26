{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.development;
in
{
  options.${namespace}.roles.development = {
    enable = mkEnableOption "Enable development configuration";

    projectsHome = mkOption {
      type = types.str;
      default = "~/Projects";
      description = "Path to the projects directory";
    };

    ai = {
      copilot = mkEnableOption "Enable GitHub Copilot AI assistant";
      claude-code = mkEnableOption "Enable Claude Code AI assistant";
    };

    languages = {
      haskell = mkEnableOption "Enable Haskell development support";
      rust = mkEnableOption "Enable Rust development support";
      python = mkEnableOption "Enable Python development support";
      go = mkEnableOption "Enable Go development support";
      typescript = mkEnableOption "Enable TypeScript development support";
      scala = mkEnableOption "Enable Scala development support";
      java = mkEnableOption "Enable Java development support";
    };

    platforms = {
      jvm = mkEnableOption "Enable JVM platform support";
      node = mkEnableOption "Enable Node.js platform support";
    };

    editors = {
      code = mkEnableOption "Enable Visual Studio Code";
      cursor = mkEnableOption "Enable Cursor editor";
      idea = mkEnableOption "Enable JetBrains IDEA";
    };

    build = {
      bazel = mkEnableOption "Enable bazel build tool";
    };

    database = {
      mysql = mkEnableOption "Enable MySQL database client";
    };

    testing = {
      testcontainers = mkEnableOption "Enable testcontainers support";
    };
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      PROJECTS_HOME = cfg.projectsHome;
    };

    ${namespace} = {
      development = {
        languages = {
          haskell.enable = cfg.languages.haskell;
          java.enable = cfg.languages.java;
          scala.enable = cfg.languages.scala;
        };
        platforms = {
          jvm.enable = cfg.platforms.jvm || cfg.languages.java || cfg.languages.scala;
          node.enable = cfg.platforms.node || cfg.languages.typescript;
        };
        editors = {
          code = {
            enable = cfg.editors.code;
            languages = {
              inherit (cfg.languages) haskell;
              inherit (cfg.languages) java;
              inherit (cfg.languages) scala;
            };
          };
          cursor = {
            enable = cfg.editors.cursor;
            languages = {
              inherit (cfg.languages) haskell;
              inherit (cfg.languages) java;
              inherit (cfg.languages) scala;
            };
          };
          idea.enable = cfg.editors.idea;
        };
        ai = {
          claude-code.enable = cfg.ai.claude-code;
        };
        build = {
          bazel.enable = cfg.build.bazel;
        };
        database = {
          mysql.enable = cfg.database.mysql;
        };

        testing = {
          testcontainers.enable = cfg.testing.testcontainers;
        };

      };
      cli = {
        editors.nvim = {
          enable = true;
          ai = {
            inherit (cfg.ai) copilot;
            # TODO: claude-code nvim plugin bundles the claude-code CLI via nixvim's
            # extraPackages, causing a full npm build. Disable until we can decouple
            # the plugin from the CLI (which is managed separately via Homebrew or home-manager).
            # inherit (cfg.ai) claude-code;
          };
          development = {
            inherit (cfg.languages) haskell;
            inherit (cfg.languages) rust;
            inherit (cfg.languages) python;
            inherit (cfg.languages) go;
            inherit (cfg.languages) typescript;
            inherit (cfg.languages) scala;
            inherit (cfg.languages) java;
          };
        };
        # Only dev-specific tools here; the interactive-shell essentials
        # (eza, bat, zoxide, fzf, starship, modern-unix, network-tools) come
        # from the common role, which every development host also enables.
        tools = {
          coreutils.enable = true;
          moreutils.enable = true;
          atuin.enable = true;
          bottom.enable = true;
          direnv.enable = true;
          # githubToken (GITHUB_TOKEN) left off: GITHUB_TOKEN shadows the keyring OAuth
          # login, and the classic PAT it carries is rejected by SSO orgs.
          # Interactive machines use `gh auth login` instead.
          # Enable githubToken per-host on headless servers that have no keyring.
          gh.enable = true;
          git.enable = true;
          htop.enable = true;
          nix-index.enable = true;
          yazi.enable = true;
          # Terminal multiplexer — persistent, reattachable sessions. Useful on
          # any dev host and required for the agent host (attach over SSH).
          zellij.enable = true;
        };
      };

      virtualization = {
        podman.enable = true;
        k8s.enable = true;
      };

    };
  };
}
