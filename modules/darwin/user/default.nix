{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.user;
in
{
  options.${namespace}.user = with types; {
    enable = mkBoolOpt true "Whether to configure user";
    name = mkOpt str defaults.user "Username (must match existing account)";
  };

  config = mkIf cfg.enable {
    # User already exists (managed by organization)
    # Just configure home-manager integration
    users.users.${cfg.name} = {
      home = "/Users/${cfg.name}";
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
}
