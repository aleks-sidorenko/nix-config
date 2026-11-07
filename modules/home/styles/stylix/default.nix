{
  lib,
  pkgs,
  config,
  inputs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.styles.stylix;

  # Shared font configuration (works on both platforms)
  fontConfig = {
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
in
{
  imports = with inputs; [
    stylix.homeModules.stylix
    catppuccin.homeModules.catppuccin
  ];

  options.${namespace}.styles.stylix = {
    enable = lib.mkEnableOption "Enable stylix style manager";

    wallpaper = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum pkgs.${namespace}.wallpapers.names);
      default = null;
      description = ''
        Name of the wallpaper from the wallpapers registry. When null,
        stylix.image is not set by this module.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # The catppuccin module is imported on every home, so this is set even
      # with stylix off: a home that leaves `autoEnable` unset gets a warning.
      catppuccin = {
        flavor = "mocha";
        # catppuccin/nix is moving to autoEnable-driven port enrollment with
        # `enable` as the global toggle. Opt out of auto-enrollment and keep
        # only the ports we enable explicitly (fish, ghostty, ...).
        enable = true;
        autoEnable = false;
      };

      # Homes reuse the system's pkgs (useGlobalPkgs), which ignores a home's
      # nixpkgs.overlays, so these never applied; defining them only warns.
      stylix.overlays.enable = false;
    }

    (lib.mkIf cfg.enable (
      lib.mkMerge [
        # NixOS (Linux): full stylix configuration
        (lib.mkIf pkgs.stdenv.isLinux {
          stylix = {
            enable = true;
            autoEnable = true;
            base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

            image = lib.mkIf (cfg.wallpaper != null) pkgs.${namespace}.wallpapers.${cfg.wallpaper};

            iconTheme = {
              enable = true;
              package = pkgs.catppuccin-papirus-folders.override {
                flavor = "mocha";
                accent = "lavender";
              };
              dark = "Papirus-Dark";
            };

            cursor = {
              name = "Bibata-Modern-Classic";
              package = pkgs.bibata-cursors;
              size = 24;
            };

            fonts = fontConfig;
          };
        })

        # Darwin (macOS): minimal safe stylix (no autoEnable, only fonts)
        (lib.mkIf pkgs.stdenv.isDarwin {
          stylix = {
            enable = true;
            # IMPORTANT: autoEnable pulls in NixOS (Linux)-only dependencies (xdotool, etc.)
            autoEnable = false;
            base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

            image = lib.mkIf (cfg.wallpaper != null) pkgs.${namespace}.wallpapers.${cfg.wallpaper};

            # Only fonts - icons and cursors have NixOS (Linux)-only dependencies
            fonts = fontConfig;
          };

          # Manually enable safe targets for Darwin (macOS)
          stylix.targets = {
            # Terminal emulators (config-based, no package dependencies)
            bat.enable = true;
            fzf.enable = true;
            lazygit.enable = true;
            # These are safe as they only generate config files, no NixOS (Linux)-specific packages
            fish.enable = true;
            nixvim.enable = true;
            vscode.enable = true;
          };

          ${namespace}.desktops.wallpaper.enable = true;
        })
      ]
    ))
  ];
}
