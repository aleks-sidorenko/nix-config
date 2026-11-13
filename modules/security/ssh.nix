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

    persist.files = [
      hostKey
      "${hostKey}.pub"
    ];
  };
}
