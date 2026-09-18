{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
rec {
  ## Option type for one OpenVPN client connection, shared by the darwin and
  ## NixOS consumers so that a host's call site is identical on both platforms.
  ##
  ## The profile is referenced as an opaque SOPS secret rather than described
  ## field by field: .ovpn profiles inline <key>, so the whole file is secret
  ## and cannot be split into public config plus separate credentials. Tweaks
  ## are therefore expressed as command-line overrides (openvpnExtraArgs)
  ## instead of by rewriting the profile.
  ##
  ## ```nix
  ## mkOpt (attrsOf (submodule openvpnConnection)) { } "Connections."
  ## ```
  #@ AttrSet -> AttrSet
  openvpnConnection =
    { name, ... }:
    {
      options = with types; {
        profileSecret =
          mkOpt str "system-vpn-${name}-profile"
            "Name of the SOPS secret holding the whole .ovpn profile.";
        autoStart = mkBoolOpt false "Connect at boot rather than on demand.";
        splitTunnel = mkBoolOpt true "Refuse a server-pushed redirect-gateway, so only the VPN's own routes are installed and an existing default route (e.g. a corporate VPN's) keeps winning.";
        ignorePushedDns = mkBoolOpt true "Refuse server-pushed DNS servers. macOS has no resolvconf, so a pushed resolver needs an up-script to apply at all; refusing it keeps the host's own DNS intact.";
        extraConfig = mkOpt (listOf str) [ ] "Extra openvpn command-line arguments.";
      };
    };

  ## The openvpn command-line arguments implied by a connection's options.
  ## Passed after --config, so the profile stays an opaque secret we never
  ## parse or rewrite.
  ##
  ## ```nix
  ## openvpnExtraArgs config.nix-config.services.networking.openvpn.connections.kpi
  ## ```
  #@ AttrSet -> [String]
  openvpnExtraArgs =
    conn:
    # --pull-filter matches the prefix of each pushed option, so
    # "redirect-gateway" also covers "redirect-gateway def1 bypass-dhcp".
    optionals conn.splitTunnel [
      "--pull-filter"
      "ignore"
      "redirect-gateway"
    ]
    ++ optionals conn.ignorePushedDns [
      "--pull-filter"
      "ignore"
      "dhcp-option DNS"
    ]
    ++ conn.extraConfig;
}
