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
  dirs = map (
    dir:
    let
      parts = lib.splitString "," dir;
      dirPath = lib.last parts;
    in
    dirPath
  ) cfg.directories;
in
{
  options.${namespace}.services.media.minidlna = {
    enable = mkEnableOption "Enable MiniDLNA media server";

    directories = mkOption {
      type = (types.listOf types.str);
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

    port = mkOpt types.port 8200 "Port for the MiniDLNA web interface";

    announceInterval = mkOpt types.int 60 "Announce interval in seconds";

    strictDlna = mkOpt types.bool false "Strictly adhere to DLNA standards";

  };

  config = mkIf cfg.enable {
    services.minidlna = {
      enable = true;
      settings = {
        media_dir = cfg.directories;
        friendly_name = cfg.friendlyName;
        port = cfg.port;
        announce_interval = cfg.announceInterval;
        strict_dlna = if cfg.strictDlna then "yes" else "no";
        inotify = "yes";
        enable_tivo = "no";
        wide_links = "no";
      };
    };

    # Open firewall ports
    networking.firewall = {
      allowedTCPPorts = [
        cfg.port
        1900
      ];
      allowedUDPPorts = [ 1900 ];
    };

    users.users.minidlna = {
      extraGroups = [
        "users"
        "wheel"
      ]; # so minidlna can access the files.
    };

    # Ensure the media directories exist
    systemd.tmpfiles.rules = map (dir: "d ${dir} 0755 minidlna minidlna -") dirs;

    # Add media directories to impermanence if enabled
    environment.persistence.${persistence.root}.directories =
      mkIf config.${namespace}.disks.impermanence.enable
        dirs;
  };
}
