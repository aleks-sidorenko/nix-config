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

  sopsEnabled = config.${namespace}.security.sops.enable;
  shell = config.${namespace}.cli.shells.default.package;

  # Source of truth: the plural `users` set. The primary is the entry flagged
  # `primary = true`. This derivation must stay one-directional (plural -> the
  # singular alias below); never derive the plural default from the singular.
  primaryNames = attrNames (filterAttrs (_: u: u.primary) usersCfg);
  primaryName = if primaryNames == [ ] then null else head primaryNames;

  userSubmodule = types.submodule {
    options = with types; {
      primary = mkBoolOpt false "Whether this is the primary/admin user of the host";
      admin = mkBoolOpt false "Whether the user has sudo access (wheel group)";
      profile = mkOpt (enum [
        "adult"
        "child"
      ]) "adult" "Permission/group preset for the user";
      extraGroups = mkOpt (listOf str) [ ] "Additional groups for the user";
      extraOptions = mkOpt attrs { } "Extra options passed to users.users.<name>";
      initialPassword = mkOpt (nullOr str) null "Initial password (used when SOPS is disabled)";
      hashedPasswordFile = mkOpt (nullOr str) null "Path to a hashed password file override";
    };
  };

  # Groups everyone gets, plus profile-specific presets.
  baseGroups = [
    "networkmanager"
    "input"
    "tty"
  ];
  childGroups = [
    "audio"
    "video"
    "input"
  ];

  mkUser =
    name: u:
    let
      isPrimary = name == primaryName;

      # The singular `nix-config.user` alias is the primary's group/password
      # injection surface (podman/virtualbox/kvm and the desktop role write to
      # it). Fold those contributions into the primary account only.
      aliasGroups = optionals isPrimary userAlias.extraGroups;
      aliasInitialPassword = if isPrimary then userAlias.initialPassword else null;
      aliasHashedPasswordFile = if isPrimary then userAlias.hashedPasswordFile else null;
      aliasExtraOptions = if isPrimary then userAlias.extraOptions else { };

      initialPassword =
        if u.initialPassword != null then
          u.initialPassword
        else if aliasInitialPassword != null then
          aliasInitialPassword
        else
          name;

      hashedPasswordFile =
        if u.hashedPasswordFile != null then
          u.hashedPasswordFile
        else if aliasHashedPasswordFile != null then
          aliasHashedPasswordFile
        else if sopsEnabled then
          config.sops.secrets."user-${name}-password".path
        else
          null;

      groups = unique (
        baseGroups
        ++ optionals u.admin [ "wheel" ]
        ++ optionals (u.profile == "child") childGroups
        ++ u.extraGroups
        ++ aliasGroups
      );
    in
    {
      isNormalUser = true;
      home = "/home/${name}";
      group = "users";
      inherit shell;

      # Set either hashedPasswordFile or initialPassword, but not both
      initialPassword = mkIf (hashedPasswordFile == null) initialPassword;
      hashedPasswordFile = mkIf (hashedPasswordFile != null) hashedPasswordFile;

      extraGroups = groups;
    }
    // u.extraOptions
    // aliasExtraOptions;
in
{
  options.${namespace} = {
    users = mkOpt (types.attrsOf userSubmodule) {
      ${defaults.user} = {
        primary = true;
        admin = true;
      };
    } "Declarative user accounts for this host. Exactly one must set primary = true.";

    # Backward-compat alias: a derived view of the primary user plus the
    # writable surface that other modules use to inject groups/password into it.
    user = with types; {
      name = mkOpt str defaults.user "The primary user's account name (derived from `users`)";
      extraGroups = mkOpt (listOf str) [ ] "Extra groups to add to the primary user";
      initialPassword = mkOpt (nullOr str) null "Initial password for the primary user";
      hashedPasswordFile = mkOpt (nullOr str) null "Hashed password file for the primary user";
      extraOptions = mkOpt attrs { } "Extra options for the primary user account";
    };
  };

  config = {
    assertions = [
      {
        assertion = (length primaryNames) == 1;
        message = "Exactly one nix-config.users entry must set primary = true (found ${toString (length primaryNames)}).";
      }
      {
        assertion = all (u: !(u.profile == "child" && u.admin)) (attrValues usersCfg);
        message = "A child-profile user cannot also be admin (no wheel access).";
      }
    ];

    # Derive the singular alias name from the primary. mkDefault so a host may
    # still override it directly without an eval conflict.
    ${namespace}.user.name = mkIf (primaryName != null) (mkDefault primaryName);

    users.mutableUsers = false;
    users.users = mapAttrs mkUser usersCfg;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };

    sops.secrets = mkIf sopsEnabled (
      mapAttrs' (
        name: _:
        nameValuePair "user-${name}-password" {
          sopsFile = ../secrets.yaml;
          neededForUsers = true;
        }
      ) usersCfg
    );
  };
}
