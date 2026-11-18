{ inputs, ... }:
{
  flake-file.inputs = {
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-wallpapers = {
      url = "github:aleks-sidorenko/nix-wallpapers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  den.aspects.system.stylix = {
    # Dark mode is part of the theme.
    darwin.system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";

    homeManager =
      { config, pkgs, ... }:
      let
        wallpaper = inputs.nix-wallpapers.packages.${pkgs.stdenv.hostPlatform.system}.default.earth;
      in
      {
        imports = [
          inputs.stylix.homeModules.stylix
          inputs.catppuccin.homeModules.catppuccin
        ];

        catppuccin = {
          flavor = "mocha";
          enable = true;
          # Only the ports an aspect enables explicitly.
          autoEnable = false;
        };

        stylix = {
          enable = true;
          # autoEnable pulls in Linux-only dependencies; targets are opted in below.
          autoEnable = false;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
          image = wallpaper;
          # Homes reuse the system's pkgs (useGlobalPkgs), which ignores a home's overlays.
          overlays.enable = false;

          fonts = {
            sizes = {
              terminal = 14;
              applications = 12;
              popups = 12;
            };
            monospace = {
              name = "FiraMono Nerd Font";
              package = pkgs.nerd-fonts.fira-mono;
            };
            sansSerif = {
              name = "Fira Sans";
              package = pkgs.fira;
            };
            serif = {
              name = "Source Serif";
              package = pkgs.source-serif;
            };
            emoji = {
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };
          };

          targets = {
            bat.enable = true;
            fzf.enable = true;
            lazygit.enable = true;
            fish.enable = true;
            nixvim.enable = true;
            vscode.enable = true;
          };
        };

        home.activation.setWallpaper = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          /usr/bin/osascript -e '
            tell application "System Events"
              tell every desktop to set picture to "${config.stylix.image}"
            end tell
          '
        '';
      };
  };
}
