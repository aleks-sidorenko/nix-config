let
  webPort = 8083;
  dataDir = "/var/lib/calibre-web";
  user = "calibre-web";
in
{
  den.aspects.services.calibre-web = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("calibre-web.service")'' ];

    vhosts = [
      {
        name = "calibre";
        port = webPort;
        # Books and comics can be large.
        clientMaxBodySize = "512m";
      }
    ];

    nixos =
      { host, pkgs, ... }:
      let
        media = import ./_media.nix host.mediaRoot;
        libraryDir = media.mediaDir media.categories.books;
      in
      {
        users.groups.${media.group} = { };

        services.calibre-web = {
          enable = true;
          inherit user dataDir;
          inherit (media) group;
          listen = {
            # The proxy connects over IPv4; upstream defaults to ::1.
            ip = "127.0.0.1";
            port = webPort;
          };
          openFirewall = false;
          options = {
            calibreLibrary = libraryDir;
            enableBookUploading = true;
            enableBookConversion = true;
            enableKepubify = true;
          };
        };

        # A separate oneshot rather than a preStart: upstream's ExecStartPre
        # checks metadata.db, and ours must run before it.
        systemd.services.calibre-init = {
          description = "Initialize an empty Calibre library";
          before = [ "calibre-web.service" ];
          requiredBy = [ "calibre-web.service" ];
          # calibredb needs a writable HOME; the service user has none.
          environment.HOME = dataDir;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = user;
            Group = media.group;
          };
          script = ''
            if [ ! -f "${libraryDir}/metadata.db" ]; then
              ${pkgs.calibre}/bin/calibredb --with-library="${libraryDir}" list >/dev/null
            fi
          '';
        };

        systemd.tmpfiles.rules = [
          "d ${libraryDir} 0775 ${user} ${media.group} -"
        ];

        # calibredb and ebook-convert.
        environment.systemPackages = [ pkgs.calibre ];
      };
  };
}
