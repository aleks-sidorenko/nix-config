{ den, ... }:
let
  dataDir = "/var/lib/recyclarr";
  user = "recyclarr";
in
{
  den.aspects.services.recyclarr = {
    # It syncs their profiles with their API keys.
    includes = [
      den.aspects.services.sonarr
      den.aspects.services.radarr
    ];
    persist.directories = [ dataDir ];
    # The sync itself needs network the install test VM lacks.
    installChecks = [ ''machine.succeed("systemctl is-active recyclarr.timer")'' ];

    nixos =
      {
        config,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        media = import ./_media.nix host.mediaRoot;
        inherit (media) group;
        package = pkgs.unstable.recyclarr;

        # Direct to the local apps: they disable auth for local addresses, and
        # going through the proxy would couple the sync to it.
        sonarrUrl = "http://localhost:${toString config.services.sonarr.settings.server.port}";
        radarrUrl = "http://localhost:${toString config.services.radarr.settings.server.port}";

        # Stock TRaSH HD profiles by trash_id, with the qualities overridden so
        # 720p is the target and 1080p only a fallback: 720p groups rank above
        # 1080p, and the cutoff stops upgrades once 720p is reached.
        recyclarrConfig = ''
          sonarr:
            tv:
              base_url: ${sonarrUrl}
              api_key: ${config.sops.placeholder."service-sonarr-api-key"}
              quality_definition:
                type: series
              quality_profiles:
                - trash_id: 72dae194fc92bf828f32cde7744e51a1 # WEB-1080p
                  reset_unmatched_scores:
                    enabled: true
                  upgrade:
                    allowed: true
                    until_quality: WEB 720p
                  qualities:
                    - name: WEB 720p
                      qualities: [WEBDL-720p, WEBRip-720p]
                    - name: Bluray-720p
                    - name: WEB 1080p
                      qualities: [WEBDL-1080p, WEBRip-1080p]
                    - name: Bluray-1080p
              custom_format_groups:
                add:
                  - trash_id: 158188097a58d7687dee647e04af0da3 # [Optional] Golden Rule HD
                  - trash_id: 74aff4168620ed49dcc67e92b2c2a5b4 # [Optional] Language Profiles
                  - trash_id: 85fae4a2294965b75710ef2989c850eb # [Streaming Services] HD/UHD boost
                  - trash_id: 59c3af66780d08332fdc64e68297098f # [Unwanted] Unwanted Formats
          radarr:
            movies:
              base_url: ${radarrUrl}
              api_key: ${config.sops.placeholder."service-radarr-api-key"}
              quality_definition:
                type: movie
              quality_profiles:
                - trash_id: d1d67249d3890e49bc12e275d989a7e9 # HD Bluray + WEB
                  reset_unmatched_scores:
                    enabled: true
                  upgrade:
                    allowed: true
                    until_quality: WEB 720p
                  qualities:
                    - name: WEB 720p
                      qualities: [WEBDL-720p, WEBRip-720p]
                    - name: Bluray-720p
                    - name: WEB 1080p
                      qualities: [WEBDL-1080p, WEBRip-1080p]
                    - name: Bluray-1080p
              custom_format_groups:
                add:
                  - trash_id: f8bf8eab4617f12dfdbd16303d8da245 # [Optional] Golden Rule HD
                  - trash_id: a3ac6af01d78e4f21fcb75f601ac96df # [Unwanted] Unwanted Formats
        '';
      in
      {
        # Reuses the secrets sonarr and radarr declare.
        sops.templates."recyclarr.yml" = {
          content = recyclarrConfig;
          owner = user;
          inherit group;
          mode = "0400";
        };

        users.groups.${group} = { };
        users.users.${user} = {
          isSystemUser = true;
          inherit group;
          home = dataDir;
          createHome = true;
          description = "Recyclarr sync user";
        };

        systemd = {
          tmpfiles.rules = [ "d ${dataDir} 0755 ${user} ${group} -" ];

          services.recyclarr = {
            description = "Recyclarr TRaSH Guides sync";
            after = [
              "network-online.target"
              "sonarr.service"
              "radarr.service"
            ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "oneshot";
              User = user;
              Group = group;
              Environment = [
                "RECYCLARR_CONFIG_DIR=${dataDir}"
                "RECYCLARR_DATA_DIR=${dataDir}"
              ];
              ExecStart = "${lib.getExe package} sync --config ${config.sops.templates."recyclarr.yml".path}";
            };
          };

          timers.recyclarr = {
            description = "Scheduled Recyclarr TRaSH Guides sync";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "daily";
              Persistent = true;
            };
          };
        };

        environment.systemPackages = [ package ];
      };
  };
}
