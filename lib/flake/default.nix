{
  lib,
  namespace,
  ...
}:
with lib.${namespace};
rec {

  # Returns the appropriate flake directory path based on the context:
  # - For home-manager modules: returns $HOME based path
  # - For NixOS modules: returns absolute path using user name from config
  # - For shells/other contexts: returns $HOME based path if no config provided
  flakeDir =
    config:
    toString (
      if (config == null) || (config == { }) || (config ? home-manager) then
        /. + "$HOME/.${namespace}" # Use /. + to convert string to path
      else
        /. + "/home/${config.${namespace}.user.name}/.${namespace}"
    );
}
