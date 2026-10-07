{
  lib,
  inputs,
  namespace,
  ...
}:
let
  inherit (inputs) terranix;

  inherit (lib.${namespace}) defaults;

  ## Fails the build if any `import[].to` in the rendered terraform JSON names
  ## a resource address absent from `resource`. Neither `tofu validate` nor
  ## `nix flake check` on their own catch this class of bug.
  ##
  #@ { pkgs: Pkgs, name: String, json: Path } -> Derivation
  mkImportCheck =
    {
      pkgs,
      name,
      json,
    }:
    pkgs.runCommand "${name}-import-check" { nativeBuildInputs = [ pkgs.jq ]; } ''
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
  ## The state-encryption block, as HCL rather than part of the terranix
  ## config: OpenTofu's JSON syntax has no equivalent for the two-label
  ## `key_provider "pbkdf2" "state"` form, so this stays a sibling `.tf`
  ## file — generated into the state dir next to `config.tf.json` so the
  ## three consumers share one copy instead of each tracking their own.
  ##
  #@ Pkgs -> Derivation
  stateEncryptionFile =
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
in
{
  ## Provider, version and credential variables for the Tailscale API, for
  ## every config that reads the tailnet. Import it rather than restating the
  ## block; the variable names are what `secrets` must map onto.
  ##
  #@ Module
  tailscaleProvider = {
    terraform.required_providers.tailscale = {
      source = "tailscale/tailscale";
      version = "~> 0.17";
    };

    variable = {
      tailscale_oauth_client_id.type = "string";
      tailscale_oauth_client_secret = {
        type = "string";
        sensitive = true;
      };
    };

    provider.tailscale = {
      oauth_client_id = "\${var.tailscale_oauth_client_id}";
      oauth_client_secret = "\${var.tailscale_oauth_client_secret}";
      tailnet = defaults.network.domains.tailnet;
    };
  };

  ## Provider, version and credential variable for the Cloudflare API, for
  ## every config that manages the account. Import it rather than restating
  ## the block; `secrets` must map `TF_VAR_cloudflare_api_token`.
  ##
  #@ Module
  cloudflareProvider = {
    terraform.required_providers.cloudflare = {
      source = "cloudflare/cloudflare";
      version = "~> 5.20";
    };

    variable.cloudflare_api_token = {
      type = "string";
      sensitive = true;
    };

    provider.cloudflare = {
      api_token = "\${var.cloudflare_api_token}";
    };
  };

  ## Wrap a terranix configuration in show/validate/plan/apply/destroy scripts.
  ##
  ## State lives in the repo under `stateDir`; secrets are decrypted from
  ## `secretsFile` into the environment variables named by `secrets`.
  ##
  #@ { pkgs: Pkgs, system: String, name: String, modules: [Module],
  #@   stateDir: String, secretsFile: String ? null, secrets: Attrs ? {} } -> Derivation
  mkTerraformDerivation =
    {
      pkgs,
      system,
      name,
      modules,
      stateDir,
      secretsFile ? null,
      secrets ? { },
    }:
    let
      # Declared here rather than by each caller: the encryption file below
      # references it, and the two travel together.
      stateEncryptionVar = lib.optional (secrets ? TF_VAR_state_passphrase) {
        variable.state_passphrase = {
          type = "string";
          sensitive = true;
        };
      };

      terraformConfiguration = terranix.lib.terranixConfiguration {
        inherit system;
        modules = stateEncryptionVar ++ modules;
        extraArgs = { inherit lib pkgs; };
      };

      tofu = lib.getExe pkgs.opentofu;
      sops = lib.getExe pkgs.sops;

      resolveRoot = ''
        if [[ -z "''${FLAKE_DIR:-}" ]]; then
          echo "Error: FLAKE_DIR not set. Export it to the flake root directory."
          exit 1
        fi
        REPO_ROOT="$FLAKE_DIR"
      '';

      loadSecrets =
        if secretsFile != null && secrets != { } then
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              envVar: sopsKey:
              # Bare assignment honors `set -e`; `export VAR=$(...)` would not,
              # letting a failed decrypt export an empty secret silently.
              ''
                ${envVar}=$(${sops} -d --extract '["${sopsKey}"]' "$REPO_ROOT/${secretsFile}")
                export ${envVar}
              '') secrets
          )
        else
          "";

      setup = ''
        cd "$REPO_ROOT/${stateDir}"
        cp -f ${terraformConfiguration} config.tf.json
      ''
      + lib.optionalString (secrets ? TF_VAR_state_passphrase) ''
        cp -f ${stateEncryptionFile pkgs} encryption.tf
      '';

      script =
        suffix: body:
        pkgs.writeShellScriptBin "${name}-${suffix}" ''
          set -euo pipefail
          ${resolveRoot}
          ${loadSecrets}
          ${setup}
          ${tofu} init -input=false
          ${body} "$@"
        '';
    in
    (pkgs.writeShellScriptBin "${name}-show" ''
      set -euo pipefail
      ${lib.getExe pkgs.jq} . ${terraformConfiguration}
    '')
    // {
      # `validate` checks syntax and provider schema only — it never resolves
      # `import` blocks, so a dangling import target still passes this and
      # only fails at `plan`.
      validate = script "validate" "${tofu} validate";
      plan = script "plan" "${tofu} plan";
      apply = script "apply" "${tofu} apply";
      destroy = script "destroy" "${tofu} destroy";
      # Closes exactly the gap `validate`'s comment above names: pure and
      # offline (evaluates `terraformConfiguration` fresh, never the
      # checked-in state-dir cache, which can go stale — see git history of
      # this file), so it runs in `nix flake check` with no device/network.
      check = mkImportCheck {
        inherit pkgs name;
        json = terraformConfiguration;
      };
    };
}
