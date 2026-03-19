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
            inherit (cfg.ai) claude-code;
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
        multiplexers.zellij.enable = true;

        tools = {
          moreutils.enable = true;
          atuin.enable = true;
          bat.enable = true;
          bottom.enable = true;
          direnv.enable = true;
          eza.enable = true;
          fzf.enable = true;
          git.enable = true;
          htop.enable = true;
          modern-unix.enable = true;
          network-tools.enable = true;
          nix-index.enable = true;
          starship.enable = true;
          yazi.enable = true;
          zoxide.enable = true;
        };
      };

      virtualization = {
        podman.enable = true;
        k8s.enable = true;
      };

    };
  };
}
