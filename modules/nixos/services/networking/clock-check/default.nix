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
  cfg = config.${namespace}.services.networking.clock-check;
  thresholdMs = toString (cfg.threshold * 1000);

  # nixpkgs builds htpdate without TLS. HTTPS with certificate checks keeps a
  # captive portal or proxy from answering with a wrong Date header.
  htpdate = pkgs.htpdate.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.openssl ];
    buildFlags = [ "https" ];
  });

  # htpdate's daemon steps the clock only on its first sync and slews after
  # that, so a guest that slept for hours would take weeks to catch up. Query
  # instead, and step only past the threshold: smaller offsets are timesyncd's,
  # which is more precise whenever NTP gets through.
  check = pkgs.writeShellApplication {
    name = "clock-check";
    runtimeInputs = [
      htpdate
      pkgs.gawk
    ];
    text = ''
      servers=(${escapeShellArgs cfg.servers})

      if ! offset_ms=$(htpdate -q -c "''${servers[@]}" | awk '/^Offset/ { print $2 }') || [ -z "$offset_ms" ]; then
        echo "no server answered; clock left alone"
        exit 0
      fi

      if awk -v o="$offset_ms" -v t="${thresholdMs}" 'BEGIN { exit !(o > t || o < -t) }'; then
        echo "clock off by ''${offset_ms} ms; stepping"
        htpdate -s -c "''${servers[@]}"
      else
        echo "clock off by ''${offset_ms} ms; within ${toString cfg.threshold} s"
      fi
    '';
  };
in
{
  options.${namespace}.services.networking.clock-check = with types; {
    enable = mkBoolOpt false "Step the clock from HTTPS Date headers when it drifts past a threshold";
    servers = mkOpt (listOf str) [
      "https://www.cloudflare.com"
      "https://www.google.com"
    ] "HTTPS servers whose Date header is trusted";
    threshold = mkOpt ints.positive 10 "Offset in seconds beyond which the clock is stepped";
    interval = mkOpt str "5min" "How often to check";
  };

  config = mkIf cfg.enable {
    systemd.services.clock-check = {
      description = "Step the clock over HTTPS when it has drifted";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = getExe check;
      };
    };

    systemd.timers.clock-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.interval;
      };
    };
  };
}
