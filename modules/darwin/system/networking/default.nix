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

  # Stock macOS /etc/hosts (no registry entries: MagicDNS + the lan zone
  # resolve those now, and /etc/hosts is consulted before DNS, so a stale
  # entry here would keep resolving a host to an address it no longer has).
  hostsText = ''
    ##
    # Host Database
    ##
    127.0.0.1 localhost
    255.255.255.255 broadcasthost
    ::1 localhost
  '';
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networking";
    knownNetworkServices = mkOpt (listOf str) [ "Wi-Fi" ] "List of macOS network services to configure";
    domains = {
      lan = mkOpt str defaults.network.domains.lan "LAN domain for intranet resolution";
      public = mkOpt str defaults.network.domains.public "Public domain to search for";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      inherit (cfg) knownNetworkServices;

      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      search = [
        defaults.network.domains.tailnet
        cfg.domains.lan
      ];
    };

    # nix-darwin cannot manage /etc/hosts via environment.etc (symlink) because
    # macOS ships a real /etc/hosts and the resolver expects a regular file
    # (nix-darwin#1035). Instead, overwrite it as a real file on every
    # activation so no stale entry survives a rebuild.
    system.activationScripts.postActivation.text = ''
      printf >&2 'resetting /etc/hosts...\n'
      printf '%s' ${lib.escapeShellArg hostsText} > /etc/hosts
      chmod 0644 /etc/hosts
    '';
  };
}
