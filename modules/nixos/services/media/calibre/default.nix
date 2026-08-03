{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.media.calibre;
in
{
  options.${namespace}.services.media.calibre = {
    enable = mkEnableOption "Enable Calibre book library";

    user = mkOpt types.str "calibre-web" "User to run Calibre as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Calibre as";

    libraryDir = mkOpt types.str "/data/media/Books" "Calibre library directory (contains metadata.db)";

    dataDir = mkOpt types.str "/var/lib/calibre-web" "Directory where Calibre stores its app data";

    package = mkOpt types.package pkgs.calibre-web "Calibre package to use";

    webPort = mkOpt types.port defaults.network.ports.calibre.web "Port for the Calibre web interface";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      services.networking.nginx = {
        virtualHosts = {
          calibre = {
            serverName = hosts.local "books";
            port = cfg.webPort;
            # Books/comics can be large; allow big uploads through the proxy.
            clientMaxBodySize = "512m";
          };
        };
      };
    };

    # Upstream nixpkgs module is named `calibre-web`; we expose it under our own
    # `calibre` namespace for simplicity.
    services.calibre-web = {
      inherit (cfg) enable;
      inherit (cfg) package;
      listen = {
        # nginx proxies to 127.0.0.1; upstream defaults to ::1 which would not connect.
        ip = "127.0.0.1";
        port = cfg.webPort;
      };
      inherit (cfg) user;
      inherit (cfg) group;
      inherit (cfg) dataDir;
      # Access is via nginx only; do not expose the raw port on the firewall.
      openFirewall = false;
      options = {
        calibreLibrary = cfg.libraryDir;
        enableBookUploading = true;
        enableBookConversion = true;
        enableKepubify = true;
      };
    };

    # Bootstrap an empty Calibre library if none exists, so the calibre-web
    # service's ExecStartPre metadata.db check passes on a fresh deploy. A separate
    # oneshot (before + requiredBy calibre-web.service) is used instead of a preStart
    # so we avoid the ExecStartPre-concatenation ordering hazard (our init must run
    # before upstream's metadata.db check).
    systemd.services.calibre-init = {
      description = "Initialize an empty Calibre library";
      before = [ "calibre-web.service" ];
      requiredBy = [ "calibre-web.service" ];
      # calibredb needs a writable HOME (~/.config/calibre); the service user has
      # none, so point it at the dataDir (created by upstream tmpfiles before
      # services start).
      environment.HOME = cfg.dataDir;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = cfg.group;
      };
      script = ''
        if [ ! -f "${cfg.libraryDir}/metadata.db" ]; then
          echo "No Calibre library at ${cfg.libraryDir}; creating an empty one..."
          ${pkgs.calibre}/bin/calibredb --with-library="${cfg.libraryDir}" list >/dev/null
        fi
      '';
    };

    # Create the library directory (owned by the service user/media group) before
    # the init unit runs. Do NOT declare dataDir here — upstream already does.
    systemd.tmpfiles.rules = [
      "d ${cfg.libraryDir} 0775 ${cfg.user} ${cfg.group} -"
    ];

    # calibredb (bootstrap + migration) and ebook-convert.
    environment.systemPackages = [ pkgs.calibre ];
  };
}
