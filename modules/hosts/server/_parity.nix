# What `server` is compared with `master` on. Evaluated against both trees, so
# it reads only options that exist on both.
{ lib }:
let
  # Only the declarative fields: disko adds functions and `_`-prefixed internals.
  declarative =
    v:
    if builtins.isFunction v then
      null
    else if builtins.isAttrs v then
      if v ? outPath then
        "<path>"
      else
        lib.filterAttrs (_: x: x != null) (
          lib.mapAttrs (_: declarative) (lib.filterAttrs (n: _: !lib.hasPrefix "_" n) v)
        )
    else if builtins.isList v then
      map declarative v
    else
      v;

  # Store hashes differ whenever any input does; what a path names is compared,
  # and nix-diff covers what is inside it.
  normalise =
    v:
    if builtins.isString v then
      lib.concatMapStrings (p: if builtins.isList p then "/nix/store/HASH-" else p) (
        builtins.split "/nix/store/[a-z0-9]{32}-" (builtins.unsafeDiscardStringContext v)
      )
    else if builtins.isAttrs v then
      lib.mapAttrs (_: normalise) v
    else if builtins.isList v then
      map normalise v
    else
      v;

  users = [
    "qbittorrent"
    "jellyfin"
    "radarr"
    "sonarr"
    "prowlarr"
    "recyclarr"
    "minidlna"
    "calibre-web"
  ];
  units = [
    "qbittorrent"
    "radarr"
    "sonarr"
    "prowlarr"
    "recyclarr"
    "calibre-init"
    "calibre-web"
    "jellyfin"
    "minidlna"
    "flaresolverr"
  ];
  templates = [
    "radarr-config.xml"
    "sonarr-config.xml"
    "prowlarr-config.xml"
    "qbittorrent.conf"
    "recyclarr.yml"
  ];
  secrets = [
    "service-radarr-api-key"
    "service-sonarr-api-key"
    "service-prowlarr-api-key"
    "service-qbittorrent-alexander-password"
  ];
  ownedPath = "^. (/data|/var/lib/(${lib.concatStringsSep "|" users}|private/prowlarr))(/| ).*";

  project =
    config:
    normalise {
      templates = lib.genAttrs templates (t: config.sops.templates.${t}.content);
      secrets = lib.genAttrs secrets (k: {
        inherit (config.sops.secrets.${k}) owner group mode;
      });
      users = lib.genAttrs users (u: {
        inherit (config.users.users.${u})
          isSystemUser
          group
          extraGroups
          home
          createHome
          description
          ;
      });
      tmpfiles = builtins.filter (r: builtins.match ownedPath r != null) config.systemd.tmpfiles.rules;
      firewall = {
        inherit (config.networking.firewall) allowedTCPPorts allowedUDPPorts;
      };
      vhosts = lib.mapAttrs (_: v: {
        inherit (v) serverName extraConfig;
        auth = v.basicAuthFile != null;
        inherit (v.locations."/") proxyPass proxyWebsockets;
        locationExtraConfig = v.locations."/".extraConfig;
      }) (removeAttrs config.services.nginx.virtualHosts [ "_" ]);
      units =
        lib.genAttrs units (
          u:
          declarative {
            inherit (config.systemd.services.${u})
              serviceConfig
              preStart
              script
              environment
              after
              wants
              wantedBy
              before
              requiredBy
              ;
          }
        )
        // {
          recyclarr-timer = config.systemd.timers.recyclarr.timerConfig;
        };
      jellyfin = {
        inherit (config.services.jellyfin)
          hardwareAcceleration
          transcoding
          forceEncodingConfig
          user
          group
          dataDir
          cacheDir
          configDir
          logDir
          ;
      };
      # Settings that only reach the host inside a store file (minidlna.conf,
      # calibre-web's pre-start), which the units section sees as a hash.
      settings =
        declarative {
          minidlna = config.services.minidlna.settings;
          calibre-web = {
            inherit (config.services.calibre-web)
              listen
              options
              dataDir
              user
              group
              ;
            package = config.services.calibre-web.package.name;
          };
          flaresolverr = {
            inherit (config.services.flaresolverr) port openFirewall;
            package = config.services.flaresolverr.package.name;
          };
        }
        // lib.genAttrs [ "radarr" "sonarr" "prowlarr" ] (n: {
          inherit (config.services.${n}) settings dataDir;
          user = config.services.${n}.user or null;
          group = config.services.${n}.group or null;
          package = config.services.${n}.package.name;
        });
      names = config.nix-config.networking.names or config.nix-config.system.networking.names;
    };
in
{
  inherit declarative project;
}
