{ den, lib, ... }:
let
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
in
{
  den.aspects.security.ssh = {
    includes = [ den.aspects.security.authorized-keys ];

    nixos.services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        # Hosts that must accept root (installer images) override this.
        PermitRootLogin = lib.mkDefault "no";
        StreamLocalBindUnlink = "yes";
        GatewayPorts = "clientspecified";
        PermitUserEnvironment = "no";
      };
      hostKeys = [
        {
          path = hostKey;
          type = "ed25519";
        }
      ];
    };

    darwin.services.openssh.enable = true;

    homeManager =
      { user, ... }:
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;

          # A user-writable file first, so throwaway host aliases (test VMs,
          # hosts during bootstrap) need no change to this read-only config.
          # First match wins, so these override "*".
          includes = [ "config.local" ];

          # The agent that holds the keys is set by `security.gpg`.
          settings."*".User = user.identity.name;

          extraConfig = ''
            IdentityAgent "$SSH_AUTH_SOCK"

            setEnv TERM="xterm-256color"
            setEnv SHELL="fish"
          '';
        };

        home.file.".ssh/id_ed25519.pub".source = user.identity.sshKeyFile;
      };

    persist.files = [
      hostKey
      "${hostKey}.pub"
    ];
  };
}
