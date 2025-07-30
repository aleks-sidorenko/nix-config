{
  inputs,
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.mobile;
in
{
  options.${namespace}.roles.mobile = with types; {
    enable = mkEnableOption "Whether or not to enable mobile integration support for both android and ios.";
  };

  config = mkIf cfg.enable {
     home.packages = with pkgs; [
      mtpfs # for android
      jmtpfs # for android 
    ];
  };
}
