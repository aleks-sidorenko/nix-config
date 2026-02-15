{
  lib,
  namespace,
  ...
}:
with lib;
rec {

  hosts = {
    # Returns the local host name
    local = host: "${host}.${lib.${namespace}.defaults.network.domains.local}";

    # Returns the public host name
    public = host: "${host}.${lib.${namespace}.defaults.network.domains.public}";
  };

  # Derive network address from gateway IP (assumes /24)
  networkAddress =
    gateway:
    let
      parts = splitString "." gateway;
    in
    "${elemAt parts 0}.${elemAt parts 1}.${elemAt parts 2}.0";

  # Extract prefix length from CIDR notation (e.g. "10.0.0.0/24" -> 24)
  prefixLength =
    cidr:
    let
      parts = splitString "/" cidr;
    in
    toInt (elemAt parts 1);

}
