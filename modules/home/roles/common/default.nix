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
      browsers.firefox.enable = false;

      system = {
        nix.enable = true;
        locale.enable = true;
      };

      cli = {
        terminals.foot.enable = true;
        terminals.ghostty.enable = true;
        shells.fish.enable = true;
      };
      apps = {
        guis.enable = true;
        tuis.enable = true;
      };

      security = {
        sops.enable = true;
      };
      styles.stylix.enable = true;
    };


    # TODO: move this to a separate module like `cli/tools`
    home.packages = with pkgs; [
      keymapp

      src-cli
      optinix

      (hiPrio parallel)
      moreutils
      nvtopPackages.amd
      unzip
      gnupg
    ];
  };
}
