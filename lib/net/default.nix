{
  lib,
  namespace,
  ...
}:
rec {

  hosts = {
    # Returns the local host name
    local = host: "${host}.${lib.${namespace}.defaults.network.domains.local}";

    # Returns the public host name
    public = host: "${host}.${lib.${namespace}.defaults.network.domains.public}";
  };

}
