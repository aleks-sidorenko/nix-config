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

  # Pure per-entry account. The singular `nix-config.user` alias is NOT folded
  # in here; it is merged into the primary account separately (see config
  # below), letting the module system do the merging.
  mkUser =
    name: u:
    let
      hashedPasswordFile =
        if u.hashedPasswordFile != null then
          u.hashedPasswordFile
        else if sopsEnabled then
          config.sops.secrets."user-${name}-password".path
        else
          null;

      groups = unique (
        baseGroups
        ++ optionals u.admin [ "wheel" ]
        ++ optionals (u.profile == "child") childGroups
        ++ u.extraGroups
      );
    in
    {
      isNormalUser = true;
      home = "/home/${name}";
      group = "users";
      inherit shell;

      # Password comes from SOPS (or an explicit hashedPasswordFile override).
      # We never set a plaintext password: mutableUsers = false, so an
      # `initialPassword` would be translated into an insecure `password`. When
      # no hashed file is available (e.g. SOPS disabled, as on the installer ISO)
      # the account is simply left without a password here — set one via
      # `extraOptions` (e.g. initialHashedPassword) if a host needs it.
      hashedPasswordFile = mkIf (hashedPasswordFile != null) hashedPasswordFile;

      extraGroups = groups;
    }
    // u.extraOptions;

  # Everything set on the singular `nix-config.user` alias, merged onto the
  # primary account as a whole rather than property-by-property. The module
  # system concatenates extraGroups and lets explicit scalars override.
  primaryAlias = {
    inherit (userAlias) extraGroups;
  }
  // optionalAttrs (userAlias.hashedPasswordFile != null) {
    hashedPasswordFile = mkForce userAlias.hashedPasswordFile;
  }
  // userAlias.extraOptions;
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
    users.users = mkMerge [
      (mapAttrs mkUser usersCfg)
      # Fold the singular alias into the primary as a second definition; the
      # module system merges it with the base above.
      (mkIf (primaryName != null) { ${primaryName} = primaryAlias; })
    ];

    # snowfall-lib auto-creates a system user per home dir and defaults every
    # one to admin (adds `wheel`). Disable its wheel handling so `nix-config.users`
    # is the sole authority on group membership; `wheel` comes from `admin` above.
    snowfallorg.users = mapAttrs (_: _: { admin = false; }) usersCfg;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # Move pre-existing, unmanaged files aside instead of aborting activation
      # when home-manager wants to own them (e.g. stylix's forge target manages
      # ~/.config/forge/stylesheet/forge/stylesheet.css, which the Forge GNOME
      # extension may have already created at runtime). Mirrors the darwin users
      # module.
      backupFileExtension = "backup";
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
