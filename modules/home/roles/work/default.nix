{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.work;
in
{
  options.${namespace}.roles.work = {
    enable = mkEnableOption "Enable work machine configuration";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "The work role is only supported on Darwin (macOS) systems";
      }
    ];

    ${namespace} = {
      roles = {
        # The macbook role is the base for any Mac: it owns the terminal,
        # browser, aerospace and the baseline dev toolchain. The work role only
        # layers work-specific extras on top.
        macbook = enabled;

        # Work-specific additions to the baseline development toolchain.
        development = {
          languages = {
            scala = true;
            java = true;
          };
          editors = {
            idea = true;
          };
          build = {
            bazel = true;
          };
          database = {
            mysql = true;
          };
        };

        router = enabled;
      };

      services = {
        teamviewer = enabled;
      };

    };

  };
}
