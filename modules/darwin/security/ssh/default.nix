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

  # resolveIdentity is context-aware: on darwin it maps the macOS account
  # (e.g. oleksandrsy) to its identity (e.g. alexander). See identities/.
  primaryKeyFile = (resolveIdentity config).sshPublicKeyFile;
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
