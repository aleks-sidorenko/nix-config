{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.networking;

  # Render /etc/hosts from the shared host registry (lib/defaults). Each host
  # gets both its short name and its <name>.<local-domain> alias.
  hostLines = lib.mapAttrsToList (
    host: ip: "${ip} ${host} ${host}.${cfg.domains.local}"
  ) defaults.network.hosts;

  hostsText = ''
    ##
    # Host Database
    ##
    127.0.0.1 localhost
    255.255.255.255 broadcasthost
    ::1 localhost

    # Local network hosts (managed by nix-config — do not edit by hand)
  ''
  + lib.concatStringsSep "\n" hostLines
  + "\n";
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networking";
    knownNetworkServices = mkOpt (listOf str) [ "Wi-Fi" ] "List of macOS network services to configure";
    domains = {
      local = mkOpt str defaults.network.domains.local "Local domain for intranet resolution";
      public = mkOpt str defaults.network.domains.public "Public domain to search for";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      inherit (cfg) knownNetworkServices;

      dns = [
        defaults.network.gateway
      ];

      search = [
        cfg.domains.local
      ];
    };

    # nix-darwin cannot manage /etc/hosts via environment.etc (symlink) because
    # macOS ships a real /etc/hosts and the resolver expects a regular file
    # (nix-darwin#1035). Instead, overwrite it as a real file on every
    # activation from the shared host registry.
    system.activationScripts.postActivation.text = ''
      printf >&2 'setting up /etc/hosts...\n'
      printf '%s' ${lib.escapeShellArg hostsText} > /etc/hosts
      chmod 0644 /etc/hosts
    '';
  };
}
