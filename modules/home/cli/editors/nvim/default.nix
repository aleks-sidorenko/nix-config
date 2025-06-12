# TODO - consider using https://github.com/dc-tec/nixvim?tab=readme-ov-file
{
  pkgs,
  lib,
  inputs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
with inputs;
let
  cfg = config.${namespace}.cli.editors.nvim;
in
{
  imports = [
    nixvim.homeManagerModules.nixvim
  ] ++ lib.snowfall.fs.get-non-default-nix-files ./.;

  options.${namespace}.cli.editors.nvim = with types; {
    enable = mkBoolOpt false "Enable neovim editor.";
    default = mkBoolOpt false "Whether or not to use neovim as the default shell.";
  };

  config = mkIf cfg.enable {

    ${namespace}.cli.editors.default = mkIf cfg.default {
      enable = true;
      name = "nvim";
    };

    programs.neovim = {
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;
    };

    programs.nixvim = {
      enable = true;
      extraPlugins = with pkgs.vimPlugins; [ plenary-nvim ];
      plugins.web-devicons.enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };

    stylix.targets.nixvim.enable = true; # Enable Stylix for Neovim

    xdg.desktopEntries = lib.optionalAttrs pkgs.stdenv.isLinux {
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
          "text/x-c++hdr"
          "text/x-tex"
          "application/x-shellscript"
        ];
        terminal = false;
        type = "Application";
      };
    };
  };
}
