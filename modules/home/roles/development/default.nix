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

    jvm = {
      version = mkOpt types.str "21" "JDK version (17 or 21)";
    };

    editors = {
      code = mkEnableOption "Enable Visual Studio Code";
      cursor = mkEnableOption "Enable Cursor editor";
      idea = mkEnableOption "Enable JetBrains IDEA";
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
          java = {
            enable = cfg.languages.java;
            version = cfg.jvm.version;
          };
          scala.enable = cfg.languages.scala;
        };
        editors = {
          code.enable = cfg.editors.code;
          cursor.enable = cfg.editors.cursor;
          idea.enable = cfg.editors.idea;
        };
      };
      cli = {
        editors.nvim = {
          enable = true;
          ai = {
            copilot = cfg.ai.copilot;
            claude-code = cfg.ai.claude-code;
          };
          development = {
            haskell = cfg.languages.haskell;
            rust = cfg.languages.rust;
            python = cfg.languages.python;
            go = cfg.languages.go;
            typescript = cfg.languages.typescript;
            scala = cfg.languages.scala;
            java = cfg.languages.java;
          };
        };
        multiplexers.zellij.enable = true;

        tools = {
          moreutils.enable = true;
          atuin.enable = true;
          bat.enable = true;
          bottom.enable = true;
          claude-code.enable = cfg.ai.claude-code;
          database.enable = true;
          direnv.enable = true;
          eza.enable = true;
          fzf.enable = true;
          git.enable = true;
          htop.enable = true;
          modern-unix.enable = true;
          network-tools.enable = true;
          nix-index.enable = true;
          podman.enable = true;
          starship.enable = true;
          yazi.enable = true;
          zoxide.enable = true;
        };
      };
    };
  };
}
