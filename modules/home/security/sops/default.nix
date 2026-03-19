{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.sops;
  home = config.home.homeDirectory;
  secretsBase = if pkgs.stdenv.isDarwin then "${home}/.local/share/sops-nix" else "%r";
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkBoolOpt false "Whether to enable sop for secrets management";
  };

  imports = with inputs; [
    sops-nix.homeManagerModules.sops
  ];

  config = mkIf cfg.enable {
    sops = {
      gnupg = {
        home = "${home}/.gnupg";
        sshKeyPaths = [ ];
      };

      defaultSymlinkPath = "${secretsBase}/secrets";
      defaultSecretsMountPoint = "${secretsBase}/secrets.d";
    };
  };
}
