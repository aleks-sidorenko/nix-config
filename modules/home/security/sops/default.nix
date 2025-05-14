{
  config,
  lib,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.sops;
  home = config.home.homeDirectory;
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkBoolOpt false "Whether to enable sop for secrets management.";
  };

  imports = with inputs; [
    sops-nix.homeManagerModules.sops
  ];

  config = mkIf cfg.enable {
    sops = {
      age = {
        generateKey = true;
        keyFile = "${home}/.config/sops/age/keys.txt";
        sshKeyPaths = [ "${home}/.ssh/id_ed25519" ];
      };

      defaultSymlinkPath = "/run/user/1000/secrets";
      defaultSecretsMountPoint = "/run/user/1000/secrets.d";
    };
  };
}
