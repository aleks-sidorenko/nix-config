{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.pam;
in
{
  options.${namespace}.security.pam = with types; {
    enable = mkBoolOpt false "Whether to enable PAM security settings";
  };

  config = mkIf cfg.enable {
    security.pam.services.sudo_local = {
      # Authenticate sudo with Touch ID (fingerprint).
      touchIdAuth = true;
      # Make Touch ID work for sudo inside terminal multiplexers (zellij/tmux);
      # without pam_reattach the prompt silently falls back to a password.
      reattach = true;
    };
  };
}
