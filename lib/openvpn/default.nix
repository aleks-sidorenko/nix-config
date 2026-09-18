{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
rec {
  ## Option type for one OpenVPN client connection, shared by the darwin and
  ## NixOS consumers.
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
        splitTunnel = mkBoolOpt false "Refuse a server-pushed redirect-gateway, so only the VPN's own routes are installed and an existing default route keeps winning. Only useful when the server pushes subnet routes of its own.";
        ignorePushedDns = mkBoolOpt true "Refuse server-pushed DNS servers, keeping the host's own resolver.";
        extraConfig = mkOpt (listOf str) [ ] "Extra openvpn command-line arguments.";
      };
    };

  ## The openvpn command-line arguments implied by a connection's options.
  ##
  ## ```nix
  ## openvpnExtraArgs config.${namespace}.services.networking.openvpn.connections.work
  ## ```
  #@ AttrSet -> [String]
  openvpnExtraArgs =
    conn:
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
