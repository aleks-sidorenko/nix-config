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
  cfg = config.${namespace}.development.platforms.jvm;
  jdk = if cfg.version == "21" then pkgs.jdk21 else pkgs.jdk17;
in
{
  options.${namespace}.development.platforms.jvm = {
    enable = mkEnableOption "Whether or not to enable JVM platform";
    version = mkStringOpt "21" "JDK version (17 or 21)";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      JAVA_HOME = if pkgs.stdenv.isDarwin then "${jdk}/lib/openjdk" else "${jdk}";
    };

    home.packages = with pkgs; [
      jdk
    ];
  };
}
