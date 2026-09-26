{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.home-server;
in
{
  options.${namespace}.roles.home-server = {
    enable = mkEnableOption "Enable home server role";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      roles = {
        common = enabled;
        server = enabled;
        media-server = enabled;
        # Its automations name physical devices, so a host without them
        # (a VM stand-in) has to be able to opt out.
        smart-home.enable = mkDefault true;
        gaming-server = enabled;
        # A host with nowhere off-box to send backups, and nothing else dialling
        # its repository, gains nothing from either half — so both can be
        # switched off without unpicking the role.
        backup-server.enable = mkDefault true;
        backup.enable = mkDefault true;
      };
    };

  };
}
