{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.identity;

  inherit (lib.${namespace}) identityDir identityFile;

  contentIfPresent =
    name:
    let
      p = identityFile cfg.name name;
    in
    if p != null then lib.trim (builtins.readFile p) else null;
in
{
  options.${namespace}.security.identity = with types; {
    name = mkOpt str config.${namespace}.user.name ''
      Identity (folder under the top-level identities/) whose public key material
      to use. Defaults to the account username; override when one person uses
      several accounts (e.g. oleksandrsy@workbook reusing "alexander").
    '';

    available = mkOption {
      type = bool;
      readOnly = true;
      default = builtins.pathExists (identityDir cfg.name);
      description = "Whether an identities/<name>/ folder exists for this identity.";
    };

    gpgPublicKeyFile = mkOption {
      type = nullOr path;
      readOnly = true;
      default = identityFile cfg.name "gpg.pub.asc";
      description = "Path to the identity's GPG public key, or null if absent.";
    };

    gpgKeyId = mkOption {
      type = nullOr str;
      readOnly = true;
      default = contentIfPresent "gpg.key-id";
      description = "The identity's GPG key ID (exposed as the SSH key), or null.";
    };

    sshPublicKeyFile = mkOption {
      type = nullOr path;
      readOnly = true;
      default = identityFile cfg.name "ssh.pub";
      description = "Path to the identity's SSH public key, or null if absent.";
    };

    sshPublicKey = mkOption {
      type = nullOr str;
      readOnly = true;
      default = contentIfPresent "ssh.pub";
      description = "Content of the identity's SSH public key, or null if absent.";
    };
  };
}
