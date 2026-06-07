{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.sops;
  home = config.home.homeDirectory;
  secretsBase = "${home}/.local/share/sops-nix";

  # A distinct sops file is enough to prime gpg-agent: every home secret is
  # encrypted to the same key, so decrypting one caches the passphrase.
  sopsFiles = unique (mapAttrsToList (_: s: toString s.sopsFile) config.sops.secrets);

  # Resolved at eval time — the script only ever contains the line for this platform.
  restartCommand =
    if pkgs.stdenv.isDarwin then
      ''launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.sops-nix"''
    else
      "systemctl --user restart sops-nix.service";

  # Unlocks GPG (prompting + caching the passphrase in gpg-agent) then restarts
  # the sops-nix user service. Fixes the case where sops-nix runs at login before
  # gpg-agent is unlocked and decryption fails with "0 successful groups required".
  sops-fix = pkgs.writeShellApplication {
    name = "sops-fix";
    runtimeInputs = [
      pkgs.sops
      pkgs.gnupg
    ];
    text = ''
      echo "🔓 Unlocking GPG (caching passphrase in gpg-agent)..."
      ${optionalString (sopsFiles != [ ]) "sops --decrypt ${escapeShellArg (head sopsFiles)} > /dev/null"}
      echo "🔄 Restarting sops-nix user service..."
      ${restartCommand}
      echo "✅ sops-nix restarted — secrets re-materialized"
    '';
  };
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkBoolOpt false "Whether to enable sop for secrets management";
  };

  imports = with inputs; [
    sops-nix.homeManagerModules.sops
  ];

  config = mkIf cfg.enable {
    sops = {
      gnupg = {
        home = "${home}/.gnupg";
        sshKeyPaths = [ ];
      };

      defaultSymlinkPath = "${secretsBase}/secrets";
      defaultSecretsMountPoint = "${secretsBase}/secrets.d";
    };

    home.packages = [ sops-fix ];
  };
}
