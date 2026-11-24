{
  config,
  den,
  inputs,
  lib,
  withSystem,
  ...
}:
let
  stacks = config.den.stacks;
  modulesOf = name: config.flake.terranixModules.${name};

  # OpenTofu's JSON syntax has no form for the two-label
  # `key_provider "pbkdf2" "state"` block, so state encryption stays HCL.
  encryptionTf =
    pkgs:
    pkgs.writeText "encryption.tf" ''
      terraform {
        encryption {
          key_provider "pbkdf2" "state" {
            passphrase = var.state_passphrase
          }
          method "aes_gcm" "state" {
            keys = key_provider.pbkdf2.state
          }
          state {
            method = method.aes_gcm.state
          }
        }
      }
    '';

  # Secrets files resolve against the repo root, not the directory the script
  # was started from (the wrapper has already cd'd into the workdir).
  secretsScript =
    secrets:
    ''
      root=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "infra: run from inside the repository" >&2
        exit 1
      }
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (
        var: secret:
        # A bare assignment honours `set -e`; `export VAR=$(…)` would export
        # an empty secret when the decrypt fails.
        ''
          ${var}=$(sops -d --extract '["${secret.key}"]' "$root/${secret.file}")
          export ${var}
        '') secrets
    );

  prefixText =
    pkgs: name:
    secretsScript config.infraStacks.${name}.meta.secrets
    + ''
      cp -f ${encryptionTf pkgs} encryption.tf
    '';

  # Neither `tofu validate` nor the module system catches an `import` whose
  # `to` names no resource; this fails the build on one.
  importCheck =
    pkgs: name: json:
    pkgs.runCommand "infra-${name}-import-check" { nativeBuildInputs = [ pkgs.jq ]; } ''
      jq -e '
        ( [ .resource // {} | to_entries[] | .key as $t | .value | keys[] | $t + "." + . ] ) as $known
        | ( [ .import // [] | .[].to ] ) as $wanted
        | ( $wanted - $known ) as $dangling
        | if ($dangling | length) > 0 then
            error("dangling import target(s): " + ($dangling | join(", ")))
          else true end
      ' ${json} > /dev/null
      touch $out
    '';
in
{
  imports = [ inputs.terranix.flakeModule ];

  options = {
    den.stacks = lib.mkOption {
      type = lib.types.attrsOf (
        den.lib.schema.mkInstanceType { strict = den.schema.stack.isStrict; } den.schema.stack
      );
      default = { };
      description = "OpenTofu stacks: each renders its aspects' `terranix` bodies into one configuration with its own state under `infra/<name>`.";
    };

    infraStacks = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      readOnly = true;
      description = "Each stack's evaluated terranix configuration, as `{ config; meta; }`.";
    };
  };

  config = {
    flake-file.inputs.terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    den = {
      classes.terranix = { };
      # Aspects take the entity as `stack`, as they take `host`.
      reservedKeys = [ "stack" ];

      schema.stack = {
        inherits = [ den.schema.conf ];
        includes = [
          den.policies.stack
          den.aspects.infra.state
        ];
        options.settings = lib.mkOption {
          type = config.settingsType;
          default = { };
          description = "Per-stack values for the settings aspects declare, at the aspect's path.";
        };
        imports = [
          (stack: {
            options.dir = lib.mkOption {
              type = lib.types.str;
              default = "infra/${stack.config.name}";
              readOnly = true;
              description = "Repo-relative directory holding the stack's state, provider lock and own secrets.";
            };
            options.identity = lib.mkOption {
              type = config.identityType;
              description = "The person whose accounts the stack manages; only stacks whose aspects read it set it.";
            };
          })
        ];
      };

      policies = {
        to-stacks =
          _: lib.mapAttrsToList (_: stack: den.lib.policy.resolve.to "stack" { inherit stack; }) stacks;

        stack =
          { stack, ... }:
          [
            (den.lib.policy.include den.aspects.infra.${stack.name})
            (den.lib.policy.instantiate {
              name = "${stack.name}-tf";
              class = "terranix";
              instantiate = { modules, ... }: modules;
              intoAttr = [
                "terranixModules"
                stack.name
              ];
            })
          ];
      };

      schema.flake.includes = [ den.policies.to-stacks ];
    };

    infraStacks = lib.mapAttrs (
      name: _:
      let
        evaluated = withSystem "x86_64-linux" (
          { pkgs, ... }:
          inputs.terranix.lib.evalTerranixConfiguration {
            inherit pkgs;
            modules = modulesOf name;
          }
        );
      in
      {
        inherit (evaluated) config;
        meta = evaluated._meta;
      }
    ) stacks;

    perSystem =
      { config, pkgs, ... }:
      {
        terranix = {
          exportDevShells = false;
          terranixConfigurations = lib.mapAttrs (name: stack: {
            modules = modulesOf name;
            workdir = stack.dir;
            terraformWrapper = {
              package = pkgs.opentofu;
              extraRuntimeInputs = [
                pkgs.git
                pkgs.sops
              ];
              prefixText = prefixText pkgs name;
            };
          }) stacks;
        };

        checks = lib.mapAttrs' (
          name: tf: lib.nameValuePair "infra-${name}" (importCheck pkgs name tf.result.terraformConfiguration)
        ) config.terranix.terranixConfigurations;
      };

    evalTests.infra-stacks = {
      expr = lib.attrNames stacks;
      expected = [
        "dns"
        "github"
        "storage"
        "tailnet"
      ];
    };

    evalTests.infra-wrapper-fails-on-decrypt =
      let
        prefix =
          config.allSystems.x86_64-linux.terranix.terranixConfigurations.storage.terraformWrapper.prefixText;
        assigned = builtins.match ".*TF_VAR_state_passphrase=\\$\\(.*\nexport TF_VAR_state_passphrase\n.*" prefix;
      in
      {
        expr = {
          assignsThenExports = assigned != null;
          exportsAssignment = lib.hasInfix "export TF_VAR_state_passphrase=$(" prefix;
        };
        expected = {
          assignsThenExports = true;
          exportsAssignment = false;
        };
      };
  };
}
