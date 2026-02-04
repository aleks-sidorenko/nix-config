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
    enable = mkOpt types.bool false "Whether to configure Java development.";
    version = mkOpt types.str "21" "JDK version (17 or 21)";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      JAVA_HOME = if pkgs.stdenv.isDarwin then "${jdk}/lib/openjdk" else "${jdk}";
    };

    home.packages = with pkgs; [
      jdk
      gradle
      maven
      bazelisk
    ];

    home.shellAliases = {
      bazel = "bazelisk";
    };
  };
}
