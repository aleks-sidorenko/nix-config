{
  config,
  inputs,
  lib,
  ...
}:
let
  c = (config.builders.testNixos config.flake.modules.nixos.recyclarr).config;
  yaml = c.sops.templates."recyclarr.yml".content;
in
{
  flake.modules.nixos.recyclarr =
    { config, pkgs, ... }:
    let
      user = "recyclarr";
      inherit (config.constants.media) group;
      dataDir = "/var/lib/recyclarr";
      # Unstable: needs recyclarr >= 8 for the v8 config schema (trash_id quality
      # profiles + custom_format_groups); the stable pin ships 7.x.
      package = pkgs.unstable.recyclarr;

      # Connect directly to the local Sonarr/Radarr rather than via the nginx
      # reverse proxy: nginx here is plain HTTP with no TLS, both apps disable auth
      # for local addresses, and going direct avoids coupling the sync to nginx and
      # local DNS. This is also Recyclarr's documented pattern.
      sonarrUrl = "http://localhost:${toString config.services.sonarr.settings.server.port}";
      radarrUrl = "http://localhost:${toString config.services.radarr.settings.server.port}";

      # Recyclarr configuration (TRaSH Guides sync). The quality profiles are the
      # stock TRaSH HD templates imported by trash_id (which pulls the full custom
      # format suite: release tiering, unwanted-format rejects, streaming boosts,
      # x265-HD reject, etc.), with the qualities/cutoff overridden so 720p is the
      # default target and 1080p is only accepted as a fallback. API keys are the
      # same SOPS secrets Sonarr/Radarr use, substituted in via the SOPS template.
      #
      # 720p-target quality list (inlined per instance): 720p groups rank above
      # 1080p, so a 720p release always wins; 1080p is grabbed only when no 720p
      # exists. Cutoff at "WEB 720p" stops upgrades once 720p is reached.
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
      # It reuses their API-key secrets and syncs into them.
      imports = with inputs.self.modules.nixos; [
        media-library
        sonarr
        radarr
      ];

      # The Sonarr/Radarr API keys are substituted in from the secrets those
      # services already expose, so no new SOPS entries.
      nix-config.media.users.${user} = {
        home = dataDir;
        description = "Recyclarr sync user";
        templates."recyclarr.yml" = recyclarrConfig;
      };

      systemd = {
        tmpfiles.rules = [
          "d ${dataDir} 0755 ${user} ${group} -"
        ];

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

  evalTests = {
    recyclarr-imports-arrs = {
      expr = c.services.sonarr.enable && c.services.radarr.enable;
      expected = true;
    };
    recyclarr-urls = {
      expr =
        lib.hasInfix "base_url: http://localhost:8989" yaml
        && lib.hasInfix "base_url: http://localhost:7878" yaml;
      expected = true;
    };
    recyclarr-timer = {
      expr = c.systemd.timers.recyclarr.timerConfig;
      expected = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
