{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.communication.slack;
in
{
  options.${namespace}.communication.slack = {
    enable = mkEnableOption "Enable the Slack desktop client";
  };

  # Linux only - Darwin uses homebrew casks via darwin/roles/work
  config = mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [ pkgs.slack ];
  };
}
