{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.roles.development;
in
{
  # TODO: split by areas: backend, frontend, mobile, desktop, devops,etc.
  options.${namespace}.roles.development = {
    enable = mkEnableOption "Enable development configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      cli = {
        editors.nvim.enable = true;
        multiplexers.zellij.enable = true;

        tools = {
          moreutils.enable = true;
          atuin.enable = true;
          bat.enable = true;
          bottom.enable = true;
          database.enable = true;
          direnv.enable = true;
          eza.enable = true;
          fzf.enable = true;
          git.enable = true;
          htop.enable = true;
          modern-unix.enable = true;
          network-tools.enable = true;
          nix-index.enable = true;
          podman.enable = true;
          starship.enable = true;
          yazi.enable = true;
          zoxide.enable = true;
        };
      };
    };
  };
}
