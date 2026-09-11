{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.macbook;
  # Home-manager links its GUI apps here for the primary user. Ghostty (common
  # home role) and Google Chrome come from nix.
  hmApps = "/Users/${config.${namespace}.user.name}/Applications/Home Manager Apps";
in
{
  options.${namespace}.roles.macbook = with types; {
    enable = mkEnableOption "Enable macbook configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Curated Dock: the everyday apps every macbook pins. Role-specific apps
      # (e.g. Slack from the work role) append to this via mkAfter.
      system.defaults.dock.apps = [
        "${hmApps}/Ghostty.app"
        "${hmApps}/Google Chrome.app"
      ];

      # Inherit common configuration
      roles.common = {
        enable = true;
        homebrew = {
          taps = [
          ];
          brews = [
            "mas" # Mac App Store CLI
          ];
          casks = [
            "raycast" # Spotlight replacement
          ];
        };
      };

      desktops.aerospace = enabled;

      communication = {
        viber = enabled;
        telegram = enabled;
      };

    };
  };
}
