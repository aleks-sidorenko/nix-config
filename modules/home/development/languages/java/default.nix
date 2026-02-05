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
  cfg = config.${namespace}.development.languages.java;
  jdk = if cfg.version == "21" then pkgs.jdk21 else pkgs.jdk17;
in
{
  options.${namespace}.development.languages.java = {
    enable = mkEnableOption "Whether to configure Java development";
    version = mkStringOpt "21" "JDK version (17 or 21)";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      JAVA_HOME = "${jdk}";
    };

    home.packages = with pkgs; [
      jdk
      gradle
      maven
    ];
  };
}
