{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.user;
  shell = config.${namespace}.cli.shells.default.package;
  initialPassword = cfg.initialPassword or cfg.name;

  # Use SOPS path only if SOPS is enabled and no explicit hashedPasswordFile is set
  sopsEnabled = config.${namespace}.security.sops.enable;
  hashedPasswordFile =
    if cfg.hashedPasswordFile != null then
      cfg.hashedPasswordFile
    else if sopsEnabled then
      config.sops.secrets."user-${cfg.name}-password".path
    else
      null;
in
{
  options.${namespace}.user = with types; {
    enable = mkOpt bool true "Whether to configure the user account";
    name = mkOpt str defaults.user "The name of the user's account";
    initialPassword = mkOpt (nullOr str) null "The initial password to use";
    hashedPasswordFile = mkOpt (nullOr str) null "The path to the hashed password file";
    extraGroups = mkOpt (listOf str) [ ] "Groups for the user to be assigned";
    extraOptions = mkOpt attrs { } "Extra options passed to users.users.<n>";
  };

  config = {
    users.mutableUsers = false;
    users.users.${cfg.name} = {
      isNormalUser = true;
      inherit (cfg) name;
      home = "/home/${cfg.name}";
      group = "users";
      inherit shell;

      # Set either hashedPasswordFile or initialPassword, but not both
      initialPassword = mkIf (hashedPasswordFile == null) initialPassword;
      hashedPasswordFile = mkIf (hashedPasswordFile != null) hashedPasswordFile;

      # TODO: set in modules
      extraGroups = [
        "wheel"
        "networkmanager"
        "input"
        "tty"
      ]
      ++ cfg.extraGroups;
    }
    // cfg.extraOptions;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };

    sops.secrets."user-${cfg.name}-password" = mkIf sopsEnabled {
      sopsFile = ../secrets.yaml;
      neededForUsers = true;
    };
  };
}
