{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.sops;
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkBoolOpt false "Whether to enable sop for secrets management.";
  };

  config = mkIf cfg.enable {
    sops = {
      age.sshKeyPaths = [ (persistence.getPath config "/etc/ssh/ssh_host_ed25519_key") ];
    };
  };

}
