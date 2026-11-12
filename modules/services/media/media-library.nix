{
  config,
  inputs,
  lib,
  ...
}:
let
  c =
    (config.builders.testNixos {
      imports = [ config.flake.modules.nixos.media-library ];
      nix-config.media.users.probe = {
        home = "/var/lib/probe";
        description = "Probe";
        secrets = [ "probe-secret" ];
        templates."probe.conf" = "x";
      };
    }).config;
  readableByProbe = {
    owner = "probe";
    group = "media";
    mode = "0400";
  };
in
{
  # What every media service shares: the group, the library root, and the
  # shape of their system users. Each media feature imports it, so none
  # depends on a role.
  flake.modules.nixos.media-library =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      inherit (config.constants.media) group mediaRoot;
      cfg = config.nix-config.media;
      readableBy = name: {
        owner = name;
        inherit group;
        mode = "0400";
      };
    in
    {
      imports = [ inputs.self.modules.nixos.sops ];

      options.nix-config.media.users = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              home = mkOption {
                type = types.str;
                description = "Home and data directory of the user.";
              };
              description = mkOption {
                type = types.str;
                description = "Description of the account.";
              };
              extraGroups = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Groups beyond the media group.";
              };
              secrets = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "SOPS secrets only this user can read.";
              };
              templates = mkOption {
                # Lazy: the contents read sops.placeholder, which sops-nix
                # derives only once it knows whether any template exists.
                type = types.lazyAttrsOf types.lines;
                default = { };
                description = "SOPS templates, by name, only this user can read.";
              };
            };
          }
        );
        default = { };
        description = "System users of the media services, each in the media group.";
      };

      config = {
        users.groups.${group} = lib.mkDefault { };

        # No single service owns the library root; each writes only its own
        # category directory.
        systemd.tmpfiles.rules = [ "d ${mediaRoot} 0775 root ${group} -" ];

        users.users = lib.mapAttrs (_: u: {
          isSystemUser = true;
          group = lib.mkForce group;
          inherit (u) home description extraGroups;
          createHome = true;
        }) cfg.users;

        sops.secrets = lib.mkMerge (
          lib.mapAttrsToList (name: u: lib.genAttrs u.secrets (_: readableBy name)) cfg.users
        );

        sops.templates = lib.mkMerge (
          lib.mapAttrsToList (
            name: u: lib.mapAttrs (_: content: readableBy name // { inherit content; }) u.templates
          ) cfg.users
        );
      };
    };

  evalTests = {
    media-library-group = {
      expr = c.users.groups ? media;
      expected = true;
    };
    media-library-root = {
      expr = lib.filter (lib.hasInfix "/data") c.systemd.tmpfiles.rules;
      expected = [ "d /data/media 0775 root media -" ];
    };
    media-library-user = {
      expr = {
        inherit (c.users.users.probe)
          isSystemUser
          group
          extraGroups
          home
          createHome
          ;
      };
      expected = {
        isSystemUser = true;
        group = "media";
        extraGroups = [ ];
        home = "/var/lib/probe";
        createHome = true;
      };
    };
    media-library-secret = {
      expr = {
        inherit (c.sops.secrets.probe-secret) owner group mode;
      };
      expected = readableByProbe;
    };
    media-library-template = {
      expr = {
        inherit (c.sops.templates."probe.conf") owner group mode;
      };
      expected = readableByProbe;
    };
  };
}
