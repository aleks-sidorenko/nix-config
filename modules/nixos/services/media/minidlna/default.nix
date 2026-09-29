{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.media.minidlna;
in
{
  options.${namespace}.services.media.minidlna = {
    enable = mkEnableOption "Enable MiniDLNA media server";

    directories = mkOption {
      type = types.listOf types.str;
      # "A" for audio    (eg. media_dir=A,/var/lib/minidlna/music)
      # "P" for pictures (eg. media_dir=P,/var/lib/minidlna/pictures)
      # "V" for video    (eg. media_dir=V,/var/lib/minidlna/videos)
      # "PV" for pictures and video (eg. media_dir=PV,/var/lib/minidlna/digital_camera)
      example = [
        "A,/media/Music"
        "P,/media/Pictures"
        "V,/media/Videos"
        "PV,/media/DigitalCamera"
      ];
      default = [ ];
      description = "List of directories to serve media from";
    };

    friendlyName = mkOpt types.str "Media Server" "Friendly name for the media server";

    webPort = mkOpt types.port defaults.network.ports.dlna.web "Port for the MiniDLNA web interface";

    discoveryPort =
      mkOpt types.port defaults.network.ports.dlna.discovery
        "Port for DLNA/UPnP discovery (SSDP)";

    announceInterval = mkOpt types.int 60 "Announce interval in seconds";

    strictDlna = mkOpt types.bool false "Strictly adhere to DLNA standards";

    user = mkOpt types.str "minidlna" "User to run MiniDLNA as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run minidlna as";

  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services.networking.nginx = {
        virtualHosts = {
          minidlna = {
            serverName = hosts.service "minidlna";
            port = cfg.webPort;
            # No login of its own, and the DLNA clients that need it
            # unauthenticated reach this port directly rather than through the
            # vhost, so guarding the vhost costs them nothing.
            requiresProxyAuth = true;
            # Its embedded HTTP server answers 400 to the Upgrade/Connection
            # headers the proxy adds by default.
            proxyWebsockets = false;
          };
        };
      };
    };

    services.minidlna = {
      enable = true;
      settings = {
        media_dir = cfg.directories;
        friendly_name = cfg.friendlyName;
        port = cfg.webPort;
        announce_interval = cfg.announceInterval;
        strict_dlna = if cfg.strictDlna then "yes" else "no";
        inotify = "yes";
        enable_tivo = "no";
        wide_links = "no";
        # Ensure read-only access
        root_container = "B";
      };
    };

    # DLNA clients discover the server over SSDP and then fetch media straight
    # from this port, not through the nginx vhost, so it stays open -- closing
    # it would leave the server announcing itself but unable to serve.
    networking.firewall.allowedTCPPorts = [ cfg.webPort ];

    # SSDP is UDP-only; minidlna never listens for discovery on TCP.
    networking.firewall.allowedUDPPorts = [ cfg.discoveryPort ];

    users.users.${cfg.user} = {
      group = mkForce cfg.group;
      extraGroups = [
        "users"
      ]; # so minidlna can access the files.
      description = "MiniDLNA daemon user";
    };

  };

}
