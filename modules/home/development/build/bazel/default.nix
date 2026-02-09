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
  cfg = config.${namespace}.development.build.bazel;
in
{
  options.${namespace}.development.build.bazel = {
    enable = mkEnableOption "Whether to enable bazel build tool";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      bazelisk
      buildifier
      buildozer
    ];

    home.shellAliases = {
      bazel = "bazelisk";
    };
  };
}
