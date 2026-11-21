{
  config,
  den,
  lib,
  ...
}:
let
  c = config.flake.nixosConfigurations.base-vm.config;
  me = den.hosts.x86_64-linux.base-vm.users.alexander;
in
{
  den.aspects = {
    alexander = {
      includes = [
        den.batteries.primary-user
        (den.batteries.user-shell "fish")
      ];

      # Account-level groups master grants every user beside `networkmanager`;
      # NixOS only, darwin accounts have no groups list.
      provides.to-hosts =
        { user, ... }:
        {
          nixos.users.users.${user.userName}.extraGroups = [
            "input"
            "tty"
          ];
        };
    };

    # The same person on the org-managed work Mac, under the org's account name.
    "alexander@workbook" = {
      # The host's roles carry the home config; host-scope `homeManager` reaches no one otherwise.
      includes = [ den.batteries.host-aspects ];

      homeManager = {
        # Manages the home on its own; harmless beside the system integration.
        programs.home-manager.enable = true;
        home.sessionPath = [ "$HOME/.local/bin" ];
      };

      # The account is org-managed: darwin cannot create it, only manage it,
      # and needs its uid to know which one it is.
      provides.to-hosts =
        { user, ... }:
        {
          darwin.users = {
            knownUsers = [ user.userName ];
            users.${user.userName} = {
              uid = 501;
              # nix-darwin hides the users it manages; this one logs in at the window.
              isHidden = false;
            };
          };
        };
    };
  };

  evalTests = {
    # Against the files themselves, so the hosts' tests can trust the record.
    alexander-identity = {
      expr = {
        inherit (me.identity)
          name
          sshKey
          sshKeyFile
          gpgKeyId
          gpgKeyFile
          git
          ;
      };
      expected = {
        name = "alexander";
        sshKey = lib.trim (builtins.readFile ../../identities/alexander/ssh.pub);
        sshKeyFile = ../../identities/alexander/ssh.pub;
        gpgKeyId = lib.trim (builtins.readFile ../../identities/alexander/gpg.key-id);
        gpgKeyFile = ../../identities/alexander/gpg.pub.asc;
        git = builtins.fromJSON (builtins.readFile ../../identities/alexander/git.json);
      };
    };
    alexander-wheel = {
      expr = lib.elem "wheel" c.users.users.alexander.extraGroups;
      expected = true;
    };
    alexander-groups = {
      expr = lib.subtractLists c.users.users.alexander.extraGroups [
        "input"
        "tty"
      ];
      expected = [ ];
    };
    alexander-shell = {
      expr = lib.getName c.users.users.alexander.shell;
      expected = "fish";
    };
    alexander-ssh-key = {
      expr = c.users.users.alexander.openssh.authorizedKeys.keys;
      expected = [ me.identity.sshKey ];
    };
    password-from-sops = {
      expr = c.users.users.alexander.hashedPasswordFile;
      expected = "/run/secrets-for-users/user-alexander-password";
    };
  };
}
