{
  flake.modules.nixos.ssh =
    { lib, ... }:
    {
      services.openssh = {
        enable = true;

        settings = {
          PasswordAuthentication = false;
          # Hosts that must accept root (installer images) override this.
          PermitRootLogin = lib.mkDefault "no";
          # Automatically remove stale sockets
          StreamLocalBindUnlink = "yes";
          # Allow forwarding ports to everywhere
          GatewayPorts = "clientspecified";
          PermitUserEnvironment = "no";
        };

        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
    };
}
