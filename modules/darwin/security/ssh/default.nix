{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.ssh;
in
{
  options.${namespace}.security.ssh = with types; {
    enable = mkBoolOpt false "Enable SSH";
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ (builtins.readFile ../../../home/security/ssh/id_ed25519.pub) ];
      description = "List of SSH public keys to authorize";
    };
  };

  config = mkIf cfg.enable {
    services.openssh.enable = true;

    users.users.${config.${namespace}.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
  };
}
