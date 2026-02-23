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
  #
  # secrets: attrset mapping TF_VAR env names to SOPS key names
  #   e.g. { TF_VAR_routeros_password = "router-api-password"; }
  # secretsFile: path to the SOPS-encrypted secrets.yaml
  mkTerranixDerivation =
    {
      pkgs,
      system,
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

      # Generate shell code to decrypt secrets from SOPS and export as env vars
      loadSecrets =
        if secretsFile != null && secrets != { } then
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              envVar: sopsKey: ''export ${envVar}=$(${sops} -d --extract '["${sopsKey}"]' "${secretsFile}")''
            ) secrets
          )
        else
          "";

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
        ${loadSecrets}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} plan
      '';

      apply = pkgs.writeShellScriptBin "apply" ''
        set -euo pipefail
        ${loadSecrets}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} apply
      '';

      destroy = pkgs.writeShellScriptBin "destroy" ''
        set -euo pipefail
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
