{
  lib,
  namespace,
  ...
}:
with lib.${namespace};
let

  hasAnyAttr = attrs: config: lib.any (opt: lib.hasAttrByPath (lib.splitString "." opt) config) attrs;

  # Function to check the evaluation context
  isHomeManager =
    config:
    let
      # Check for home-manager specific options
      options = [
        "home" # home-manager's main namespace
        "xdg" # xdg config is typically in home-manager
      ];

    in
    hasAnyAttr options config;

  # Function to check for system context
  isNixOS =
    config:
    let
      # Check for NixOS system specific options
      options = [
        "system" # system.* namespace
        "boot" # boot.* configuration
        "networking" # networking.* configuration
        "environment" # environment.* configuration
      ];

    in
    hasAnyAttr options config;

in
{
  # Public interface
  isHomeManager = isHomeContext;
  isNixOS = isNixOS;

  # Combined check that returns a string for convenience
  getContext =
    config:
    if isHomeManager config then
      "home"
    else if isNixOS config then
      "nixos"
    else
      "unknown";

  userName = config: (homeConfig config).home.username;

  homeDir = config: (homeConfig config).home.homeDirectory;

  homeConfig =
    config:
    if isHomeManager config then
      config
    else
      snowfallorg.users.${config.${namespace}.user.name}.home.config;
}
