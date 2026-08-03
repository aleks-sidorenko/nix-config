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
  cfg = config.${namespace}.services.media.calibre-web;
in
{
  options.${namespace}.services.media.calibre-web = {
    enable = mkEnableOption "Enable Calibre-Web book library";

    user = mkOpt types.str "calibre-web" "User to run Calibre-Web as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Calibre-Web as";

    libraryDir = mkOpt types.str "/data/media/Books" "Calibre library directory (contains metadata.db)";

    dataDir = mkOpt types.str "/var/lib/calibre-web" "Directory where Calibre-Web stores its app data";

    package = mkOpt types.package pkgs.calibre-web "Calibre-Web package to use";

    webPort =
      mkOpt types.port defaults.network.ports.calibre-web.web
        "Port for the Calibre-Web web interface";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      services.networking.nginx = {
        virtualHosts = {
          calibre-web = {
            serverName = hosts.local "books";
            port = cfg.webPort;
            # Books/comics can be large; allow big uploads through the proxy.
            clientMaxBodySize = "512m";
          };
        };
      };
    };

    services.calibre-web = {
      enable = true;
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

    # Bootstrap an empty Calibre library if none exists, so calibre-web's
    # ExecStartPre metadata.db check passes on a fresh deploy. A separate oneshot
    # (before + requiredBy calibre-web) is used instead of a preStart so we avoid
    # the ExecStartPre-concatenation ordering hazard (our init must run before
    # upstream's metadata.db check). Ownership is handled by the tmpfiles rule +
    # User=calibre-web, so no explicit chown is needed here.
    systemd.services.calibre-web-init = {
      description = "Initialize an empty Calibre library for Calibre-Web";
      before = [ "calibre-web.service" ];
      requiredBy = [ "calibre-web.service" ];
      serviceConfig = {
        Type = "oneshot";
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
