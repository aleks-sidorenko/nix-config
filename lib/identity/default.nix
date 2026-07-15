{ ... }:
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
}
