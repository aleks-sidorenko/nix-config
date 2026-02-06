{
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.virtualization.podman;
in
{
  options.${namespace}.virtualization.podman = with types; {
    enable = mkBoolOpt false "Whether or not to manage podman";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      arion
      podman
      podman-compose
      podman-tui
      amazon-ecr-credential-helper
    ];
  };
}
