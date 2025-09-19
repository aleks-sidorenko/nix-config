{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.media;
  enabled =
    config.${namespace}.services.media.minidlna.enable
    || config.${namespace}.services.media.qbittorrent.enable
    || config.${namespace}.services.media.jellyfin.enable
    || config.${namespace}.services.media.radarr.enable
    || config.${namespace}.services.media.sonarr.enable;

in
{
  options.${namespace}.services.media = {
    enable = mkBoolOpt enabled "Enable media media services.";
    group = mkOpt types.str "media" "Group to run media services as";
  };

  config = mkIf cfg.enable {
    # Create the shared media group
    users.groups.${cfg.group} = mkDefault { };

  };

}
