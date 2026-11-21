{ inputs, lib, ... }:
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
    settings = {
      flavor = lib.mkOption {
        type = lib.types.enum [
          "latte"
          "frappe"
          "macchiato"
          "mocha"
        ];
        default = "mocha";
        description = "Catppuccin flavor; the base16 scheme follows it.";
      };
      wallpaper = lib.mkOption {
        type = lib.types.str;
        default = "earth";
        description = "Name of a wallpaper in the nix-wallpapers set.";
      };
    };

    # Dark mode is part of the theme.
    darwin.system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";

    homeManager =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        inherit (host.settings.system.stylix) flavor wallpaper;
        wallpapers = inputs.nix-wallpapers.packages.${pkgs.stdenv.hostPlatform.system}.default;
      in
      {
        imports = [
          inputs.stylix.homeModules.stylix
          inputs.catppuccin.homeModules.catppuccin
        ];

        catppuccin = {
          inherit flavor;
          enable = true;
          # Only the ports an aspect enables explicitly.
          autoEnable = false;
        };

        stylix = {
          enable = true;
          # autoEnable pulls in Linux-only dependencies; targets are opted in below.
          autoEnable = false;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-${flavor}.yaml";
          image = wallpapers.${wallpaper};
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
