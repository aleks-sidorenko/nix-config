{ lib, ... }:
let
  # Also the SSH agent's cache lifetime: the key signs commits and logs in.
  cacheTtl = 86400;
in
{
  den.aspects.security.gpg.homeManager =
    { pkgs, user, ... }:
    let
      identity = ../../identities/${user.identity};
    in
    {
      # gpg-agent is the ssh agent: the identity's authentication subkey is
      # exposed through it, so ssh and git's ssh signing find the key there.
      services.gpg-agent = {
        enable = true;
        enableSshSupport = true;
        enableExtraSocket = true;
        sshKeys = [ (lib.trim (builtins.readFile (identity + "/gpg.key-id"))) ];
        defaultCacheTtl = cacheTtl;
        defaultCacheTtlSsh = cacheTtl;
        maxCacheTtl = cacheTtl;
        maxCacheTtlSsh = cacheTtl;
        pinentry.package = pkgs.pinentry-curses;
        extraConfig = ''
          allow-preset-passphrase
          ttyname $GPG_TTY
        '';
      };

      home = {
        packages = [ pkgs.gnupg ];
        sessionVariables = {
          SSH_AUTH_SOCK = "$(gpgconf --list-dirs agent-ssh-socket)";
          GPG_TTY = "$(tty)";
        };
      };

      programs = {
        gpg = {
          enable = true;
          settings.trust-model = "tofu+pgp";
          # A path, not a string: it must be copied into the store to exist after a remote deploy.
          publicKeys = [
            {
              source = identity + "/gpg.pub.asc";
              trust = "ultimate";
            }
          ];
        };
        # The agent holds the keys; ssh adding its own would shadow it.
        ssh.matchBlocks."*".addKeysToAgent = lib.mkForce "no";
        keychain.enable = lib.mkForce false;
        # A shell started later must hand the agent its own tty for pinentry.
        fish.interactiveShellInit = "gpg-connect-agent updatestartuptty /bye >/dev/null";
      };
    };
}
