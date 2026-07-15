{
  lib,
  namespace,
  ...
}:
with lib;
let

  hasAllAttr = attrs: config: lib.all (opt: lib.hasAttrByPath (lib.splitString "." opt) config) attrs;

in
rec {
  # Function to check the evaluation context
  isHomeManager =
    config:
    let
      # Check for home-manager specific options
      options = [
        "home" # home-manager's main namespace
      ];

    in
    # Only return true if we have home-manager options but NOT NixOS options
    hasAllAttr options config && !(isNixOS config);

  # Function to check for system context
  isNixOS =
    config:
    let
      # Check for NixOS system specific options
      options = [
        "system" # system.* namespace
        "boot" # boot.* configuration
        "home-manager" # home-manager is also used in NixOS
      ];

    in
    hasAllAttr options config;

  # Combined check that returns a string for convenience
  getContext =
    config:
    # Check NixOS first to be explicit about priority, even though isHomeManager now handles this
    if isNixOS config then
      "nixos"
    else if isHomeManager config then
      "home"
    else
      "unknown";

  userName =
    config:
    if isHomeManager config then
      config.home.username
    else if isNixOS config then
      config.${namespace}.user.name
    else
      throw "Failed to get user name for this context";

  homeDir =
    config:
    let
      cfg = homeConfig config;
    in
    cfg.home.homeDirectory;

  # The identity a config resolves to (folder under identities/). Like userName,
  # but honors the home-only `security.identity.name` override — e.g. the
  # oleksandrsy@workbook account maps to the "alexander" identity. Falls back to
  # the username when there is no home config (e.g. a headless server).
  identityName =
    config:
    if isHomeManager config then
      config.${namespace}.security.identity.name
    else
      let
        user = config.${namespace}.user.name;
        home = config.home-manager.users.${user} or null;
      in
      if home != null then (home.${namespace}.security.identity.name or user) else user;

  homeConfig =
    config:
    if isHomeManager config then
      config
    else
      let
        cfg = config.home-manager.users.${config.${namespace}.user.name};
      in
      if !isHomeManager cfg then
        throw "Expected home-manager config in config.home-manager.users.${config.${namespace}.user.name}, but got something else"
      else
        cfg;

}
