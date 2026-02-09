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
in
{
  options.${namespace}.user = with types; {
    enable = mkBoolOpt true "Whether to configure user";
    name = mkOpt str defaults.user "Username (must match existing account)";
    uid = mkOpt int 501 "User ID (required for knownUsers)";
    shell = mkOpt (nullOr package) null "Default shell package for the user";
    extraGroups = mkOpt (listOf str) [ ] "Additional groups for the user";
  };

  config = mkIf cfg.enable {
    # Set primary user for nix-darwin user-specific options
    system.primaryUser = cfg.name;

    # User already exists (managed by organization)
    # Just configure home-manager integration
    # knownUsers is required for nix-darwin to manage the user's shell
    users.knownUsers = [ cfg.name ];
    users.users.${cfg.name} = {
      uid = cfg.uid;
      home = "/Users/${cfg.name}";
      shell = mkIf (cfg.shell != null) cfg.shell;
    };

    # Add user to extra groups
    users.groups = builtins.listToAttrs (
      map (group: {
        name = group;
        value.members = [ cfg.name ];
      }) cfg.extraGroups
    );

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
    };
  };
}
