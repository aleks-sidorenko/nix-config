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
  cfg = config.${namespace}.cli.shells;
in
{
  options.${namespace}.cli.shells = with types; {
    enable = mkBoolOpt false "Whether or not to enable the default shell configuration.";
    shell = mkPackageOpt pkgs.fish "The default shell package to use for the current user.";
  };

  config = {
    ${namespace}.cli.shells = mkIf cfg.enable {
      fish = enabled;
    };
  };
}
