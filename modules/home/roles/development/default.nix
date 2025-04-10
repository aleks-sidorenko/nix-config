{
  lib,
  config,
  namespace,
  ...
}:
with lib; let
  cfg = config.${namespace}.roles.development;
in {
  options.${namespace}.roles.development = {
    enable = mkEnableOption "Enable development configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      cli = {
        editors.nvim.enable = true;
        multiplexers.zellij.enable = true;

        tools = {        
          atuin.enable = true;
          bat.enable = true;
          bottom.enable = true;
          db.enable = true;
          direnv.enable = true;
          eza.enable = true;
          fzf.enable = true;
          git.enable = true;
          gpg.enable = true;
          htop.enable = true;
          k8s.enable = true;
          modern-unix.enable = true;
          network-tools.enable = true;
          nix-index.enable = true;
          podman.enable = true;
          ssh.enable = true;
          starship.enable = true;
          yazi.enable = true;
          zoxide.enable = true;
        };
      };
    };
  };
}
