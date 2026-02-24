{
  lib,
  inputs,
  ...
}:
rec {
  # Recursively find all default.nix files in a directory tree
  findDefaultNixFiles =
    path:
    let
      scanDir =
        dir:
        let
          entries = builtins.readDir dir;
          files = builtins.filter (name: entries.${name} == "regular" && name == "default.nix") (
            builtins.attrNames entries
          );
          filePaths = builtins.map (file: "${dir}/${file}") files;
          subDirs = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
          subDirPaths = builtins.concatLists (builtins.map (subDir: scanDir "${dir}/${subDir}") subDirs);
        in
        filePaths ++ subDirPaths;
    in
    scanDir path;

  # Create a terranix derivation with passthru scripts for show/plan/apply/destroy.
  # Uses OpenTofu for native state encryption (configured in terranix modules).
  #
  # name:               derivation name (used in `nix run .#<name>`)
  # modules:            list of terranix module paths
  # terraformModulesPath: directory to auto-discover default.nix modules from
  # stateDir:           relative path from repo root where OpenTofu state lives
  # secretsFile:        relative path from repo root to SOPS-encrypted secrets
  # secrets:            attrset mapping env var names to SOPS key names
  #                     e.g. { TF_VAR_password = "my-password"; }
  # extraArgs:          extra arguments passed to terranix modules
  mkTerranixDerivation =
    {
      pkgs,
      system,
      name ? "infra",
      extraArgs ? { },
      modules,
      terraformModulesPath ? null,
      stateDir ? ".",
      secretsFile ? null,
      secrets ? { },
    }:
    let
      globalModules =
        if terraformModulesPath != null then findDefaultNixFiles terraformModulesPath else [ ];

      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        extraArgs = {
          inherit lib pkgs;
        }
        // extraArgs;
        modules = globalModules ++ modules;
      };

      tofu = "${pkgs.opentofu}/bin/tofu";
      sops = "${pkgs.sops}/bin/sops";

      # Resolve repo root at runtime so paths work outside the nix store
      resolveRoot = ''
        if [[ -z "''${FLAKE_DIR:-}" ]]; then
          echo "Error: FLAKE_DIR not set. Export it to the flake root directory."
          exit 1
        fi
        REPO_ROOT="$FLAKE_DIR"
      '';

      # Generate shell code to decrypt secrets from SOPS and export as env vars
      loadSecrets =
        if secretsFile != null && secrets != { } then
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              envVar: sopsKey: ''export ${envVar}=$(${sops} -d --extract '["${sopsKey}"]' "$REPO_ROOT/${secretsFile}")''
            ) secrets
          )
        else
          "";

      tfSetup = ''
        cd "$REPO_ROOT/${stateDir}"
        cp -f ${terraformConfiguration} config.tf.json
      '';

      show = pkgs.writeShellScriptBin "${name}-show" ''
        set -euo pipefail
        cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
      '';

      plan = pkgs.writeShellScriptBin "${name}-plan" ''
        set -euo pipefail
        ${resolveRoot}
        ${loadSecrets}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} plan
      '';

      apply = pkgs.writeShellScriptBin "${name}-apply" ''
        set -euo pipefail
        ${resolveRoot}
        ${loadSecrets}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} apply
      '';

      destroy = pkgs.writeShellScriptBin "${name}-destroy" ''
        set -euo pipefail
        ${resolveRoot}
        ${loadSecrets}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} destroy
      '';
    in
    show
    // {
      inherit
        plan
        apply
        destroy
        ;
    };
}
