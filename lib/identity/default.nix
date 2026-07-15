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

  ## Resolve the active identity for a home config into its public key material.
  ## The identity name comes from `${namespace}.security.identity.name` (a home
  ## option that defaults to the account username). Files/content are null when
  ## the identity has no folder under identities/.
  ##
  ## ```nix
  ## (lib.nix-config.resolveIdentity config).sshPublicKey
  ## ```
  #@ AttrSet -> AttrSet
  resolveIdentity =
    config:
    let
      name = config.${namespace}.security.identity.name;
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
}
