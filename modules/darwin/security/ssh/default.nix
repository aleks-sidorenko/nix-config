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

  # The macOS account (e.g. oleksandrsy) may map to a differently-named identity
  # (e.g. alexander); resolve it via the user's home config. See identities/.
  user = config.${namespace}.user.name;
  primaryKeyFile =
    (lib.${namespace}.resolveIdentity config.home-manager.users.${user}).sshPublicKeyFile;
in
{
  options.${namespace}.security.ssh = with types; {
    enable = mkBoolOpt false "Enable SSH";
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = lib.optional (primaryKeyFile != null) (builtins.readFile primaryKeyFile);
      description = "List of SSH public keys to authorize (defaults to the primary identity's).";
    };
  };

  config = mkIf cfg.enable {
    services.openssh.enable = true;

    users.users.${config.${namespace}.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
  };
}
