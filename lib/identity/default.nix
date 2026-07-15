{
  lib,
  namespace,
  ...
}:
let
  # This file is lib/identity/default.nix, so `../..` is the flake root, where
  # the top-level identities/ folder lives (see identities/README.md).
  # Using a path relative to this lib file (rather than snowfall's fs.get-file,
  # which returns a string) keeps the results real Nix paths, so they work
  # directly with `path`-typed consumers such as home.file.source and GPG import.
  identitiesRoot = ../../identities;
in
rec {
  ## Absolute path to an identity's folder: identities/<name>.
  ##
  ## ```nix
  ## lib.nix-config.identityDir "alexander"
  ## ```
  #@ String -> Path
  identityDir = name: identitiesRoot + "/${name}";

  ## Absolute path to a file inside an identity's folder, or null if it is absent.
  ##
  ## ```nix
  ## lib.nix-config.identityFile "alexander" "ssh.pub"
  ## ```
  #@ String -> String -> (Path | Null)
  identityFile =
    name: file:
    let
      p = identityDir name + "/${file}";
    in
    if builtins.pathExists p then p else null;

  ## Resolve an identity name into its public key material. This is the shared
  ## entry point used by every context (home, NixOS, darwin). Files/content are
  ## null when the identity has no folder under identities/.
  ##
  ## ```nix
  ## (lib.nix-config.resolveIdentityByName "alexander").sshPublicKey
  ## ```
  #@ String -> AttrSet
  resolveIdentityByName =
    name:
    let
      content =
        file:
        let
          p = identityFile name file;
        in
        if p != null then lib.trim (builtins.readFile p) else null;
    in
    {
      inherit name;
      available = builtins.pathExists (identityDir name);
      gpgPublicKeyFile = identityFile name "gpg.pub.asc";
      gpgKeyId = content "gpg.key-id";
      sshPublicKeyFile = identityFile name "ssh.pub";
      sshPublicKey = content "ssh.pub";
    };

  ## Resolve the active identity for any config (home, NixOS, or darwin). The
  ## name is determined by `lib.${namespace}.identityName` (context-aware, honors
  ## the home-only `security.identity.name` override). Convenience wrapper over
  ## `resolveIdentityByName`.
  ##
  ## ```nix
  ## (lib.nix-config.resolveIdentity config).sshPublicKey
  ## ```
  #@ AttrSet -> AttrSet
  resolveIdentity = config: resolveIdentityByName (lib.${namespace}.identityName config);
}
