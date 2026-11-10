{ config, lib, ... }:
let
  read =
    name: file:
    let
      path = ../../identities + "/${name}/${file}";
    in
    if builtins.pathExists path then path else null;
  content = path: if path == null then null else lib.trim (builtins.readFile path);

  identity =
    name:
    let
      sshPublicKeyFile = read name "ssh.pub";
    in
    {
      inherit name sshPublicKeyFile;
      sshPublicKey = content sshPublicKeyFile;
      gpgPublicKeyFile = read name "gpg.pub.asc";
      gpgKeyId = content (read name "gpg.key-id");
    };
in
{
  flake.lib = { inherit identity; };

  evalTests = {
    identity-ssh-key = {
      expr = (config.flake.lib.identity "alexander").sshPublicKey;
      expected = lib.trim (builtins.readFile ../../identities/alexander/ssh.pub);
    };
    identity-missing = {
      expr = (config.flake.lib.identity "nobody").sshPublicKey;
      expected = null;
    };
  };
}
