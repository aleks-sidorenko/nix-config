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

  # Function to check for NixOS system context
  isNixOS =
    config:
    let
      # NixOS-specific: has `boot` (darwin does not)
      options = [
        "system" # system.* namespace
        "boot" # boot.* configuration (NixOS only)
        "home-manager" # home-manager is also used in NixOS
      ];

    in
    hasAllAttr options config;

  # Function to check for nix-darwin system context
  isDarwin =
    config:
    let
      # darwin-specific: has `launchd` and `system`, but no `boot`
      options = [
        "system" # system.* namespace
        "launchd" # launchd.* (nix-darwin; NixOS uses systemd)
      ];
    in
    hasAllAttr options config && !(isNixOS config);

  # Combined check that returns a string for convenience
  getContext =
    config:
    # Check system contexts first to be explicit about priority
    if isNixOS config then
      "nixos"
    else if isDarwin config then
      "darwin"
    else if isHomeManager config then
      "home"
    else
      "unknown";

  userName =
    config:
    if isHomeManager config then
      config.home.username
    else if isNixOS config || isDarwin config then
      config.${namespace}.user.name
    else
      throw "Failed to get user name for this context";

  # Home directory across contexts. Derived from the username in system contexts
  # so it works even when the user has no home-manager config (e.g. a headless
  # server), rather than requiring `homeConfig`.
  homeDir =
    config:
    if isHomeManager config then
      config.home.homeDirectory
    else if isDarwin config then
      "/Users/${userName config}"
    else
      "/home/${userName config}";

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
