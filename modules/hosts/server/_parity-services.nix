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
    isAttrs
    isList
    isPath
    isString
    split
    concatStringsSep
    unsafeDiscardStringContext
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
  unitNames = [
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
  ];
  # Hashes differ between the trees even for the same package; the name and
  # version after them, and everything else in the string, must still match.
  unhash =
    v:
    if isString v then
      concatStringsSep "" (
        map (part: if isList part then "/nix/store/" else part) (
          split "/nix/store/[0-9a-z]{32}-" (unsafeDiscardStringContext v)
        )
      )
    else if isPath v || isAttrs v && v ? outPath then
      unhash (toString v)
    else if isList v then
      map unhash v
    else
      v;
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
  # A set: the primary-user battery and the network aspect both grant a group.
  primaryGroups = attrNames (
    listToAttrs (
      map (g: {
        name = g;
        value = null;
      }) c.users.users.alexander.extraGroups
    )
  );
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
    filter (
      n:
      c.systemd.services.${n}.enable && elem "multi-user.target" (c.systemd.services.${n}.wantedBy or [ ])
    ) unitNames
  );
  unitFields =
    pick
      (
        unitNames
        ++ [
          "recyclarr"
          "restic-backups-default"
        ]
      )
      (
        n:
        let
          sc = c.systemd.services.${n}.serviceConfig or { };
        in
        mapAttrs (_: unhash) {
          ExecStart = sc.ExecStart or null;
          ExecStartPre = sc.ExecStartPre or null;
          WorkingDirectory = sc.WorkingDirectory or null;
          User = sc.User or null;
          Group = sc.Group or null;
          ReadWritePaths = sc.ReadWritePaths or null;
          StateDirectory = sc.StateDirectory or null;
        }
      );
  jellyfin = {
    inherit (c.services.jellyfin)
      dataDir
      configDir
      cacheDir
      logDir
      ;
  };
  timers = sorted (
    filter (n: c.systemd.timers ? ${n}) [
      "recyclarr"
      "restic-backups-default"
      "nh-clean"
    ]
  );
}
