{
  config,
  inputs,
  ...
}:
let
  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        calibre
        sops
        nginx
      ];
    }).config;
in
{
  flake.modules.nixos.calibre =
    { config, pkgs, ... }:
    let
      media = config.nix-config.media;
      user = "calibre-web";
      inherit (media) group;
      libraryDir = media.mediaDir media.categories.books;
      dataDir = "/var/lib/calibre-web";
    in
    {
      imports = [ inputs.self.modules.nixos.media-library ];

      nix-config.nginx.virtualHosts.calibre = {
        inherit (config.services.calibre-web.listen) port;
        # Books/comics can be large; allow big uploads through the proxy.
        clientMaxBodySize = "512m";
      };

      services.calibre-web = {
        enable = true;
        package = pkgs.calibre-web;
        listen = {
          # nginx proxies to 127.0.0.1; upstream defaults to ::1 which would not connect.
          ip = "127.0.0.1";
          port = 8083;
        };
        inherit user group dataDir;
        # Access is via nginx only; do not expose the raw port on the firewall.
        openFirewall = false;
        options = {
          calibreLibrary = libraryDir;
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
        environment.HOME = dataDir;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = user;
          Group = group;
        };
        script = ''
          if [ ! -f "${libraryDir}/metadata.db" ]; then
            echo "No Calibre library at ${libraryDir}; creating an empty one..."
            ${pkgs.calibre}/bin/calibredb --with-library="${libraryDir}" list >/dev/null
          fi
        '';
      };

      # Create the library directory (owned by the service user/media group) before
      # the init unit runs. Do NOT declare dataDir here — upstream already does.
      systemd.tmpfiles.rules = [
        "d ${libraryDir} 0775 ${user} ${group} -"
      ];

      # calibredb (bootstrap + migration) and ebook-convert.
      environment.systemPackages = [ pkgs.calibre ];
    };

  evalTests = {
    calibre-library = {
      expr = c.services.calibre-web.options.calibreLibrary;
      expected = "/data/media/Books";
    };
    calibre-init-before = {
      expr = c.systemd.services.calibre-init.requiredBy;
      expected = [ "calibre-web.service" ];
    };
  };
}
