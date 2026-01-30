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
  cfg = config.${namespace}.development.java;
  jdk = if cfg.version == "21" then pkgs.jdk21 else pkgs.jdk17;
in
{
  options.${namespace}.development.java = {
    enable = mkOpt types.bool false "Whether to configure Java development.";
    version = mkOpt types.str "21" "JDK version (17 or 21)";
    ide = mkOpt types.bool true "Whether to install JetBrains IDEA";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      JAVA_HOME = if pkgs.stdenv.isDarwin then "${jdk}/lib/openjdk" else "${jdk}";
    };

    home.packages =
      with pkgs;
      [
        jdk
        gradle
        maven
      ]
      ++ optionals cfg.ide [
        jetbrains.idea
      ];
  };
}
