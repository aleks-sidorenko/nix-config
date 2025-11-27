{
  pkgs,
  lib,
  inputs,
  config,
  namespace,
  system,
  ...
}:
with lib;
with lib.${namespace};
with inputs;
let
  cfg = config.${namespace}.cli.editors.nvim;

  nvim' = inputs.self.packages.${system}.nvim;

  nvim = nvim'.extend {
    viAlias = lib.mkForce true;
    vimAlias = lib.mkForce true;
    
    # Pass development options from the home configuration
    config.development = {
      haskell.enable = lib.mkIf (cfg.development.haskell) (lib.mkForce true);
      rust.enable = lib.mkIf (cfg.development.rust) (lib.mkForce true);
      python.enable = lib.mkIf (cfg.development.python) (lib.mkForce true);
      go.enable = lib.mkIf (cfg.development.go) (lib.mkForce true);
      typescript.enable = lib.mkIf (cfg.development.typescript) (lib.mkForce true);
    };
  };
in
{

  options.${namespace}.cli.editors.nvim = with types; {
    enable = mkEnableOption "Enable neovim editor.";
    default = mkBoolOpt false "Whether or not to use neovim as the default shell.";
    
    development = {
      haskell = mkEnableOption "Enable Haskell development support in Neovim.";
      rust = mkEnableOption "Enable Rust development support in Neovim.";
      python = mkEnableOption "Enable Python development support in Neovim.";
      go = mkEnableOption "Enable Go development support in Neovim.";
      typescript = mkEnableOption "Enable TypeScript development support in Neovim.";
    };
  };

  config = mkIf cfg.enable {

    ${namespace}.cli.editors.default = mkIf cfg.default {
      enable = true;
      name = "nvim";
    };

    # If I want to explose minimal versions of this to different systems, there is .extend.appstream
    # https://github.com/nix-community/nixvim/blob/05331006/docs/platforms/standalone.md#extending-an-existing-configuration
    home.packages = [
      nvim
    ];

    # Covered with nixvim.vimdiffAlias
    home.shellAliases.vimdiff = "nvim -d";

    stylix.targets.nixvim.enable = true; # Enable Stylix for Neovim

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
