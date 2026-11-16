# Facts both trees must agree on for `server`; evaluated against master and the branch.
c:
let
  inherit (builtins)
    attrNames
    listToAttrs
    mapAttrs
    filter
    elem
    sort
    lessThan
    ;
  sorted = sort lessThan;
  serviceUsers = [
    "calibre-web"
    "jellyfin"
    "minecraft"
    "minidlna"
    "nginx"
    "prowlarr"
    "qbittorrent"
    "radarr"
    "recyclarr"
    "restic"
    "sonarr"
  ];
  pick =
    names: f:
    listToAttrs (
      map (n: {
        name = n;
        value = f n;
      }) names
    );
in
{
  users = pick serviceUsers (
    n:
    let
      u = c.users.users.${n};
    in
    {
      inherit (u) group isSystemUser home;
      extraGroups = sorted u.extraGroups;
    }
  );
  primaryGroups = sorted c.users.users.alexander.extraGroups;
  firewall = {
    tcp = sorted c.networking.firewall.allowedTCPPorts;
    udp = sorted c.networking.firewall.allowedUDPPorts;
    interfaces = mapAttrs (_: i: {
      tcp = sorted i.allowedTCPPorts;
      udp = sorted i.allowedUDPPorts;
    }) c.networking.firewall.interfaces;
  };
  vhosts = mapAttrs (_: v: {
    inherit (v) serverName default;
    auth = v.basicAuthFile != null;
    proxyPass = v.locations."/".proxyPass or null;
    proxyWebsockets = v.locations."/".proxyWebsockets or false;
  }) c.services.nginx.virtualHosts;
  restic = mapAttrs (_: b: {
    inherit (b)
      pruneOpts
      timerConfig
      repository
      initialize
      ;
    paths = sorted b.paths;
    exclude = sorted b.exclude;
  }) c.services.restic.backups;
  secrets = attrNames c.sops.secrets;
  networking = {
    nm = c.networking.networkmanager.enable;
    inherit (c.networking) domain search;
    qdisc = c.boot.kernel.sysctl."net.core.default_qdisc" or null;
    cc = c.boot.kernel.sysctl."net.ipv4.tcp_congestion_control" or null;
    nmWaitOnline = c.systemd.services.NetworkManager-wait-online.enable;
    networkdWaitOnline = c.systemd.network.wait-online.enable;
    tsOpenFirewall = c.services.tailscale.openFirewall;
  };
  locale = {
    inherit (c.time) timeZone;
    inherit (c.i18n) defaultLocale supportedLocales;
    layout = c.services.xserver.xkb.layout;
  };
  sudo = { inherit (c.security.sudo) wheelNeedsPassword execWheelOnly; };
  manager = {
    inherit (c.systemd.settings.Manager) RuntimeWatchdogSec;
    RebootWatchdogSec = c.systemd.settings.Manager.RebootWatchdogSec or null;
  };
  misc = {
    stubLd = c.environment.stub-ld.enable;
    browser = c.environment.variables.BROWSER or null;
    nixLd = c.programs.nix-ld.enable;
    nhClean = c.programs.nh.clean.enable;
    nhCleanArgs = c.programs.nh.clean.extraArgs;
    nixGc = c.nix.gc.automatic;
    bootLimit = c.boot.loader.systemd-boot.configurationLimit;
  };
  units = sorted (
    filter
      (
        n:
        c.systemd.services.${n}.enable && elem "multi-user.target" (c.systemd.services.${n}.wantedBy or [ ])
      )
      [
        "calibre-web"
        "flaresolverr"
        "jellyfin"
        "minecraft-server"
        "minidlna"
        "NetworkManager"
        "nginx"
        "prowlarr"
        "qbittorrent"
        "radarr"
        "sonarr"
        "tailscaled"
      ]
  );
  timers = sorted (
    filter (n: c.systemd.timers ? ${n}) [
      "recyclarr"
      "restic-backups-default"
      "nh-clean"
    ]
  );
}
