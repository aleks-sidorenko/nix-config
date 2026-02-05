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
    name = mkStringOpt' "The name of the default shell to use";
    package = mkPackageOpt' "The package to use for the default shell";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null && cfg.package != null;
        message = "Please specify a shell name and package in ${namespace}.cli.shells.default";
      }
    ];
  };

}
