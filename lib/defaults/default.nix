{
  lib,
  namespace,
  ...
}:
rec {

  # Defaults for configuration options
  defaults = {
    # default user name
    user = "alexander";

    # Returns the root path for persistent storage
    persistence = {
      # Returns the root path for persistent storage
      # This is used for opt-in persistence, where directories can be mounted to /persist
      # This path is used to store files that should persist across reboots
      root = "/persist";
    };

    disks = {
      boot = "boot";
      root = "root";
    };
  };

}
