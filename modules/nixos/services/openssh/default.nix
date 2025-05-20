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
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ (lib.fileContents ../../../home/security/keys/ssh/id_ed25519.pub) ];
      description = "List of SSH public keys to authorize";
    };
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
      ${config.${namespace}.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };
  };
}
