{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.openssh;
in
{
  options.${namespace}.services.openssh = with types; {
    enable = mkBoolOpt false "Enable ssh";
    authorizedKeys = mkOpt (listOf str) [ ] "The public keys to apply.";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [ 22 ];

      settings = {
        PasswordAuthentication = false;
        StreamLocalBindUnlink = "yes";
        GatewayPorts = "clientspecified";
      };
    };

    users.users = {

      ${config.${namespace}.user.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDKc1m1PDN52C+xUqCxWOwEtTCczkXeJ5POhowH9+9F9 aleks.sidorenko@gmail.com"
      ];
    };
  };
}
