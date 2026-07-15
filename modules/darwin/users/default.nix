{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace};
  usersCfg = cfg.users;
  userAlias = cfg.user;

  # Source of truth: the plural `users` set (same shape as NixOS). darwin cannot
  # create accounts (they are macOS/org-managed), so only the primary entry is
  # configured; the singular `nix-config.user` alias is derived from it.
  primaryNames = attrNames (filterAttrs (_: u: u.primary) usersCfg);
  primaryName = if primaryNames == [ ] then null else head primaryNames;

  userSubmodule = types.submodule {
    options = with types; {
      primary = mkBoolOpt false "Whether this is the primary user of the host";
      admin = mkBoolOpt false "Whether the user is an admin (macOS admin status is org-managed; accepted for API parity with NixOS)";
      extraGroups = mkOpt (listOf str) [ ] "Additional groups for the user";
      extraOptions = mkOpt attrs { } "Extra options passed to users.users.<name>";
      uid = mkOpt int 501 "User ID (required for knownUsers)";
      shell = mkOpt (nullOr package) null "Default shell package for the user";
    };
  };
in
{
  options.${namespace} = {
    users =
      mkOpt (types.attrsOf userSubmodule)
        {
          ${defaults.user} = {
            primary = true;
            admin = true;
          };
        }
        "Declarative user accounts. On darwin only the primary is configured, and the account must already exist (macOS-managed).";

    # Backward-compat alias: a derived view of the primary user plus the writable
    # surface other modules use to inject the shell/groups into it.
    user = with types; {
      name = mkOpt str defaults.user "The primary user's account name (derived from `users`)";
      extraGroups = mkOpt (listOf str) [ ] "Extra groups to add to the primary user";
      shell = mkOpt (nullOr package) null "Default shell for the primary user";
      extraOptions = mkOpt attrs { } "Extra options for the primary user account";
    };
  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = (length primaryNames) == 1;
          message = "Exactly one nix-config.users entry must set primary = true (found ${toString (length primaryNames)}).";
        }
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };
    }

    (mkIf (primaryName != null) (
      let
        primary = usersCfg.${primaryName};
        groups = unique (primary.extraGroups ++ userAlias.extraGroups);
        shell = if userAlias.shell != null then userAlias.shell else primary.shell;
      in
      {
        # Derive the singular alias name from the primary (overridable).
        ${namespace}.user.name = mkDefault primaryName;

        # Set the primary user for nix-darwin user-specific options.
        system.primaryUser = primaryName;

        users = {
          # knownUsers is required for nix-darwin to manage an existing account.
          knownUsers = [ primaryName ];
          users.${primaryName} = {
            inherit (primary) uid;
            home = "/Users/${primaryName}";
            shell = mkIf (shell != null) shell;
          }
          // primary.extraOptions
          // userAlias.extraOptions;

          groups = builtins.listToAttrs (
            map (group: {
              name = group;
              value.members = [ primaryName ];
            }) groups
          );
        };
      }
    ))
  ];
}
