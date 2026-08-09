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
  cfg = config.${namespace}.roles.phone;
in
{
  options.${namespace}.roles.phone = with types; {
    enable = mkEnableOption "Android/iPhone mount + camera-roll backup tooling";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.${namespace}.phone-tools ];
  };
}
