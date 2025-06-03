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
  cfg = config.${namespace}.cli.terminals.default;
in
{
  options.${namespace}.cli.terminals.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default terminal configuration.";
    name = mkStringOpt' "The name of the default terminal to use.";
    package = mkPackageOpt' "The package to use for the default terminal.";
  };

}
