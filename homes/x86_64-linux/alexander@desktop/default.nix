{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{

  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles = {
      desktop = enabled;
    };

    user = {
      enable = true;
      name = "alexander";
    };

    security.sops.enable = mkForce false;

    desktops = {
      hyprland = {
        enable = mkForce false; # TODO - enable once fixed
      };
    };

  };

  home.stateVersion = "25.05";
}
