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
        # Backups go offsite. `backup-server` stays off unless a host is meant
        # to receive them — nothing dials a restic server of ours today.
        backup.enable = mkDefault true;
      };
    };

  };
}
