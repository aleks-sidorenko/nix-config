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
        pass.enable = true;
      };

      cli = {
        shells.fish = {
          enable = true;
          default = true;
        };
        terminals.ghostty = {
          enable = true;
          default = true;
          package = if pkgs.stdenv.isLinux then pkgs.ghostty else pkgs.ghostty-bin;
        };

        editors.nvim = {
          enable = true;
          default = true;
        };

        tools = {
          archivers.enable = true;
          modern-unix.enable = true;
          network-tools.enable = true;
        };
      };
      styles.stylix.enable = true;

    };

  };
}
