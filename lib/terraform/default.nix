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

  # Create a terranix derivation with passthru scripts for plan/apply/destroy
  # Uses OpenTofu for native state encryption (configured in terranix modules)
  mkTerranixDerivation =
    {
      pkgs,
      system,
      extraArgs ? { },
      modules,
      terraformModulesPath ? null,
      stateDir ? ".",
      envVars ? [
        "TF_VAR_routeros_password"
        "TF_VAR_wifi_password"
        "TF_VAR_state_passphrase"
      ],
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

      envCheck = lib.concatMapStringsSep "\n" (var: ''
        if [[ -z "''${${var}:-}" ]]; then
          echo "Error: ${var} not set"
          exit 1
        fi
      '') envVars;

      tfSetup = ''
        cd "${stateDir}"
        cp -f ${terraformConfiguration} config.tf.json
      '';

      show = pkgs.writeShellScriptBin "show" ''
        set -euo pipefail
        cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
      '';

      plan = pkgs.writeShellScriptBin "plan" ''
        set -euo pipefail
        ${envCheck}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} plan
      '';

      apply = pkgs.writeShellScriptBin "apply" ''
        set -euo pipefail
        ${envCheck}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} apply
      '';

      destroy = pkgs.writeShellScriptBin "destroy" ''
        set -euo pipefail
        ${envCheck}
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
