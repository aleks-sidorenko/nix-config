{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.shells.default;

in
{
  options.${namespace}.cli.shells.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default shell configuration";
    name = mkStringOpt "bash" "The name of the default shell to use";
    package = mkPackageOpt pkgs.bash "The package to use for the default shell";
  };

  config = mkIf cfg.enable {

    home.sessionVariables = {
      # SHELL = cfg.name; - this doesn't work for ssh & sudo to root user
      SHELL = lib.getExe cfg.package;
    };
  };
}
