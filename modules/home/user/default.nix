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
  cfg = config.${namespace}.user;
  # Platform-aware home directory
  defaultHome = if pkgs.stdenv.isDarwin then "/Users/${cfg.name}" else "/home/${cfg.name}";
in
{
  options.${namespace}.user = {
    enable = mkEnableOption "Whether to configure the user account";
    home = mkOpt (types.nullOr types.str) defaultHome "The user's home directory";
    name = mkOpt (types.nullOr types.str) defaults.user "The user account";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "${namespace}.user.name must be set";
        }
      ];

      home = {
        homeDirectory = mkDefault cfg.home;
        username = mkDefault cfg.name;
      };
    }
  ]);
}
