{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
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

      apps = {
        guis.enable = true;
        tuis.enable = true;
      };

      browsers.firefox.enable = false;

      
      styles.stylix.enable = true;
    };

    # TODO: move this to a separate module like `cli/tools`
    home.packages = with pkgs; [
      keymapp
    ];
  };
}
