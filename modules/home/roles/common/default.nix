{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.common;
in
{
  options.${namespace}.roles.common = {
    enable = lib.mkEnableOption "Enable common configuration";
  };

  config = lib.mkIf cfg.enable {
    ${namespace} = {
      
      system = {
        nix.enable = true;
        locale.enable = true;
      };

      security = {
        gpg.enable = true;
        ssh.enable = true;
        sops.enable = true;
      };

      cli = {
        terminals.foot.enable = true;
        terminals.ghostty.enable = true;
        shells.fish.enable = true;        
        editors.nvim.enable = true;
        tools.archivers.enable = true;
      };
      styles.stylix.enable = true;
      
    };
    
  };
}
