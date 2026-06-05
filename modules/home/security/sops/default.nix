{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.sops;
  home = config.home.homeDirectory;
  secretsBase = "${home}/.local/share/sops-nix";
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkBoolOpt false "Whether to enable sop for secrets management";
  };

  imports = with inputs; [
    sops-nix.homeManagerModules.sops
  ];

  config = mkIf cfg.enable {
    sops = {
      gnupg = {
        home = "${home}/.gnupg";
        sshKeyPaths = [ ];
      };

      defaultSymlinkPath = "${secretsBase}/secrets";
      defaultSecretsMountPoint = "${secretsBase}/secrets.d";
    };

    # On Linux, sops-nix decrypts inside a TTY-less systemd user service. With a
    # GnuPG key it defaults to graphical-session-pre.target, which can run before
    # the session environment (WAYLAND_DISPLAY) is imported, so gpg-agent has no
    # display to spawn a GUI pinentry on. Order it after graphical-session.target
    # so the first gpg-agent activation inherits the imported session env.
    systemd.user.services.sops-nix = mkIf (pkgs.stdenv.isLinux && config.gtk.enable) {
      Unit = {
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Install.WantedBy = mkForce [ "graphical-session.target" ];
    };
  };
}
