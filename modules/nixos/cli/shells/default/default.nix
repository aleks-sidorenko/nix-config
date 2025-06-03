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
    enable = mkBoolOpt false "Whether or not to enable the default shell configuration.";
    name = mkStringOpt' "The name of the default shell to use.";
    package = mkPackageOpt' "The package to use for the default shell.";
  };

}
