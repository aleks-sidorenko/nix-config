{
  lib,
  inputs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.editors.nvim;
in
{
  imports = [ inputs.nix-nvim.homeManagerModules.default ];

  options.${namespace}.cli.editors.nvim = with types; {
    enable = mkEnableOption "Enable neovim editor";
    default = mkBoolOpt false "Whether or not to use neovim as the default shell";

    development = {
      haskell = mkEnableOption "Enable Haskell development support in Neovim";
      rust = mkEnableOption "Enable Rust development support in Neovim";
      python = mkEnableOption "Enable Python development support in Neovim";
      go = mkEnableOption "Enable Go development support in Neovim";
      typescript = mkEnableOption "Enable TypeScript development support in Neovim";
      scala = mkEnableOption "Enable Scala development support in Neovim";
      java = mkEnableOption "Enable Java development support in Neovim";
    };

    ai = {
      copilot = mkEnableOption "Enable GitHub Copilot AI assistant in Neovim";
      claude-code = mkEnableOption "Enable Claude Code AI assistant in Neovim";
    };
  };

  config = mkIf cfg.enable {
    programs.nix-nvim = {
      enable = true;
      theme = "catppuccin";
      development = {
        haskell.enable = cfg.development.haskell;
        rust.enable = cfg.development.rust;
        python.enable = cfg.development.python;
        go.enable = cfg.development.go;
        typescript.enable = cfg.development.typescript;
        scala.enable = cfg.development.scala;
        java.enable = cfg.development.java;
      };
      ai = {
        copilot.enable = cfg.ai.copilot;
        claude-code.enable = cfg.ai.claude-code;
      };
    };

    ${namespace}.cli.editors.default = mkIf cfg.default {
      enable = true;
      name = "nvim";
    };

    home.shellAliases.vimdiff = "nvim -d";

    stylix.targets.nixvim.enable = mkIf config.${namespace}.styles.stylix.enable true;

    xdg.desktopEntries = lib.optionalAttrs config.${namespace}.desktops.addons.xdg.enable {
      neovim = {
        name = "Neovim";
        genericName = "editor";
        exec = "nvim -f %F";
        mimeType = [
          "text/html"
          "text/xml"
          "text/plain"
          "text/english"
          "text/x-makefile"
          "text/x-tex"
          "application/x-shellscript"
        ];
        terminal = false;
        type = "Application";
      };
    };
  };
}
