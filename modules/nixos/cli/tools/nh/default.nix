{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.tools.nh;
in {
  options.${namespace}.cli.tools.nh = with types; {
    enable = mkBoolOpt false "Whether or not to enable nh.";
  };

  config = mkIf cfg.enable {
    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "/home/${config.user.name}/nix-config";
    };
  };
}
