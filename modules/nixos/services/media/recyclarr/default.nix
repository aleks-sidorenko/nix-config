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
  cfg = config.${namespace}.services.media.recyclarr;

  sonarrCfg = config.${namespace}.services.media.sonarr;
  radarrCfg = config.${namespace}.services.media.radarr;

  sonarrUrl = "http://localhost:${toString sonarrCfg.webPort}";
  radarrUrl = "http://localhost:${toString radarrCfg.webPort}";

  stateDir = "/var/lib/recyclarr";

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
  options.${namespace}.services.media.recyclarr = {
    enable = mkEnableOption "Enable Recyclarr TRaSH Guides sync for Sonarr/Radarr";

    user = mkOpt types.str "recyclarr" "User to run Recyclarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Recyclarr as";

    package =
      mkOpt types.package pkgs.unstable.recyclarr
        "Recyclarr package to use (needs v8 config schema)";

    schedule = mkOpt types.str "daily" "systemd OnCalendar schedule for the sync";
  };

  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = sonarrCfg.enable && radarrCfg.enable;
        message = "recyclarr requires both sonarr and radarr to be enabled (it reuses their API-key secrets and syncs into them).";
      }
    ];

    # Render the config with the Sonarr/Radarr API keys substituted in. Reuses
    # the exact secrets those services already expose, so no new SOPS entries.
    sops.templates."recyclarr.yml" = {
      content = recyclarrConfig;
      owner = cfg.user;
      inherit (cfg) group;
      mode = "0400";
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      home = stateDir;
      createHome = true;
      description = "Recyclarr sync user";
    };

    systemd.services.recyclarr = {
      description = "Recyclarr TRaSH Guides sync";
      after = [
        "network-online.target"
        "sonarr.service"
        "radarr.service"
      ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "recyclarr";
        Environment = [
          "RECYCLARR_CONFIG_DIR=${stateDir}"
          "RECYCLARR_DATA_DIR=${stateDir}"
        ];
        ExecStart = "${getExe cfg.package} sync --config ${config.sops.templates."recyclarr.yml".path}";
      };
    };

    systemd.timers.recyclarr = {
      description = "Scheduled Recyclarr TRaSH Guides sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
