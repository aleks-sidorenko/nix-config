{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib.${namespace};
{

  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles = {
      desktop = enabled;
      # social = enabled;
    };

    user = {
      enable = true;
      name = "alexander";
    };

    security.sops.enable = mkForce false;

    
      desktops = {
        hyprland = {
          enable = true;
          execOnceExtras = [
            "${pkgs.trayscale}/bin/trayscale"
          ];
        };
      };
    

  };

  home.stateVersion = "25.05";
}
