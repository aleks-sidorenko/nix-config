{
  lib,
  namespace,
  ...
}:
with lib.${namespace};
{

  # Returns the appropriate flake directory path based on the context:
  # - For home-manager modules: returns $HOME based path
  # - For NixOS modules: returns absolute path using user name from config
  # - For shells/other contexts: returns $HOME based path if no config provided
  flakeDir = config: toString (/. + "${homeDir config}/.${namespace}");
}
