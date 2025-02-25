{
  lib,
  pkgs, 
  config,
  namespace,
  ...
}: 
with lib.${namespace};
{
  
  ${namespace} = {
  
    roles = {
      desktop = enabled;
      social = enabled;
      video = enabled;
    };

    user = {
      enable = true;
      name = "alexander";
    };

    desktops = {
      hyprland = {
        enable = true;
        execOnceExtras = [
          "${pkgs.trayscale}/bin/trayscale"
        ];
      };
    };

  };



  home.stateVersion = "24.11";
}
